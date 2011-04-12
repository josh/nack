assert = require 'assert'
ns     = require 'netstring'
url    = require 'url'

{Socket} = require 'net'
{Stream} = require 'stream'
{debug}  = require './util'

# A **Client** establishes a connection to a worker process.
#
# It takes a `port` and `host` or a UNIX socket path.
#
# Its API is similar to `http.Client`.
#
#     var conn = client.createConnection('/tmp/nack.sock');
#     var request = conn.request('GET', '/', {'host', 'localhost'});
#     request.end();
#     request.on('response', function (response) {
#       console.log('STATUS: ' + response.statusCode);
#       console.log('HEADERS: ' + JSON.stringify(response.headers));
#       response.on('data', function (chunk) {
#         console.log('BODY: ' + chunk);
#       });
#     });
#
exports.Client = class Client extends Socket
  constructor: ->
    super

    debug "client created"

    # Initialize outgoing array to hold pending requests
    @_outgoing = []
    # Incoming is used to point to the current response
    @_incoming = null

    self = this

    # Once we've made the connect, process the next request
    @on 'connect', -> self._processRequest()

    @on 'error', (err) ->
      if req = self._outgoing[0]
        req.emit 'error', err

    # Finalize the request on close
    @on 'close', -> self._finishRequest()

    # Initialize the response netstring parser
    @_initResponseParser()

  _initResponseParser: ->
    self = this

    nsStream = new ns.Stream this

    nsStream.on 'data', (data) ->
      if self._incoming
        self._incoming._receiveData data

    nsStream.on 'error', (exception) ->
      self._incoming = null
      self.emit 'error', exception

  _processRequest: ->
    # Process the request now if the socket is open and
    # we aren't already handling a response
    if @readyState is 'open' and !@_incoming
      if request = @_outgoing[0]
        debug "processing outgoing request 1/#{@_outgoing.length}"

        @_incoming = new ClientResponse this, request

        # Flush the request buffer into socket
        request.assignSocket @
    else
      # Try to reconnect and try again soon
      @reconnect()

  _finishRequest: ->
    debug "finishing request"

    req = @_outgoing.shift()
    req.detachSocket @

    res = @_incoming
    @_incoming = null

    if res is null or res.received is false
      req.emit 'error', new Error "Response was not received"
    else if res.completed is false and res.readable is true
      req.emit 'error', new Error "Response was not completed"

    # Anymore requests, continue processing
    if @_outgoing.length > 0
      @_processRequest()

  # Reconnect if the connection is closed.
  reconnect: ->
    if @readyState is 'closed'
      debug "connecting to #{@port}"
      @connect @port, @host

  # Start the connection and create a ClientRequest.
  request: (args...) ->
    request = new ClientRequest args...
    @_outgoing.push request
    @_processRequest()
    request

  # Proxy a `http.ServerRequest` and `http.serverResponse` between
  # the `Client`.
  proxy: (serverRequest, serverResponse, next) =>
    metaVariables = serverRequest.proxyMetaVariables ? {}
    metaVariables['REMOTE_ADDR'] ?= "#{serverRequest.connection.remoteAddress}"
    metaVariables['REMOTE_PORT'] ?= "#{serverRequest.connection.remotePort}"

    clientRequest = @request serverRequest.method, serverRequest.url,
      serverRequest.headers, metaVariables

    serverRequest.on 'data', (data) -> clientRequest.write data
    serverRequest.on 'end', -> clientRequest.end()
    serverRequest.on 'error', -> clientRequest.end()

    clientRequest.on 'error', next
    clientRequest.on 'response', (clientResponse) ->
      serverResponse.writeHead clientResponse.statusCode, clientResponse.headers
      clientResponse.pipe serverResponse

    clientRequest

# Public API for creating a **Client**
exports.createConnection = (port, host) ->
  client = new Client
  client.port = port
  client.host = host
  client

# Empty netstring signals EOF
END_OF_FILE = ns.nsWrite ""

# A **ClientRequest** is returned when `Client.request()` is called.
#
# It is a Writable Stream and responds to the conventional
# `write` and `end` methods.
#
# Its also an EventEmitter with the following events:
#
# > **Event 'response'**
# >
# > `function (response) { }`
# >
# > Emitted when a response is received to this request. This event is
# > emitted only once. The response argument will be an instance of
# > `ClientResponse`.
# >
# > **Event: 'error'**
# >
# > `function (exception) { }`
# >
# > Emitted when an error occurs.
#
exports.ClientRequest = class ClientRequest extends Stream
  constructor: (@method, @path, headers, metaVariables) ->
    debug "requesting #{@method} #{@path}"

    @writeable = true

    # Initialize writeQueue since socket is still connecting
    # net.Stream will buffer on connecting in node 0.3.x
    @_writeQueue = []

    @_parseEnv headers, metaVariables

    @write JSON.stringify @env

  _parseEnv: (headers, metaVariables) ->
    @env = {}

    @env['REQUEST_METHOD'] = @method

    {pathname, query} = url.parse @path
    @env['PATH_INFO']    = pathname
    @env['QUERY_STRING'] = query ? ""
    @env['SCRIPT_NAME']  = ""

    @env['REMOTE_ADDR'] = "0.0.0.0"
    @env['SERVER_ADDR'] = "0.0.0.0"

    if host = headers.host
      parts = headers.host.split ':'
      @env['SERVER_NAME'] = parts[0]
      @env['SERVER_PORT'] = parts[1]

    @env['SERVER_NAME'] ?= "localhost"
    @env['SERVER_PORT'] ?= "80"

    for key, value of headers
      key = key.toUpperCase().replace /-/g, '_'
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      @env[key] = value

    for key, value of metaVariables
      @env[key] = value

  assignSocket: (socket) ->
    debug "socket assigned, flushing request"
    @socket = @connection = socket
    @_flush()

  detachSocket: (socket) ->
    @writeable = false
    @socket = @connection = null

  # Write chunk to client
  write: (chunk, encoding) ->
    nsChunk = ns.nsWrite chunk, 0, chunk.length, null, 0, encoding

    if @_writeQueue
      debug "queueing #{nsChunk.length} bytes"
      @_writeQueue.push nsChunk
      # Return false because data was buffered
      false
    else if @connection
      debug "writing #{nsChunk.length} bytes"
      @connection.write nsChunk

  # Closes writting socket.
  end: (chunk, encoding) ->
    if (chunk)
      @write chunk, encoding

    flushed = if @_writeQueue
      debug "queueing close"
      @_writeQueue.push END_OF_FILE
      # Return false because data was buffered
      false
    else if @connection
      debug "closing connection"
      @connection.end END_OF_FILE

    @detachSocket @socket

    flushed

  destroy: ->
    @detachSocket @socket
    @socket.destroy()

  _flush: ->
    while @_writeQueue and @_writeQueue.length
      data = @_writeQueue.shift()

      # Close write socket when we see an empty netstring `0:,`
      if data is END_OF_FILE
        @socket.end data
      else
        debug "flushing #{data.length} bytes"
        @socket.write data

    @_writeQueue = null

    @emit 'drain'

    true

# A **ClientResponse** is emitted from the client request's
# `response` event.
#
# It is a Readable Stream and emits the conventional events:
#
# > **Event: 'data'**
# >
# > `function (chunk) { }`
# >
# > Emitted when a piece of the message body is received.
#
# > **Event: 'end'**
# >
# > `function () { }`
# >
# > Emitted exactly once for each message. No arguments. After emitted
# > no other events will be emitted on the request.
# >
# > **Event: 'error'**
# >
# > `function (exception) { }`
# >
# > Emitted when an error occurs.
#
exports.ClientResponse = class ClientResponse extends Stream
  constructor: (@socket, @request) ->
    @client      = @socket
    @readable    = true
    @received    = false
    @completed   = false
    @statusCode  = null
    @httpVersion = '1.1'
    @headers     = null
    @_buffer     = null

  _receiveData: (data) ->
    debug "received #{data.length} bytes"

    return if !@readable or @completed
    @received = true

    try
      if data.length > 0
        # The first response part is the status
        if !@statusCode
          @statusCode = parseInt data
          assert.ok @statusCode >= 100, "Status must be >= 100"

        # The second part is the JSON encoded headers
        else if !@headers
          @headers = {}

          rawHeaders = JSON.parse data
          assert.ok rawHeaders, "Headers can not be null"
          assert.equal typeof rawHeaders, 'object', "Headers must be an object"

          for k, vs of rawHeaders
            # Support legacy Array headers
            vs = vs.join "\n" if vs.join

            # Split multiline Rack headers
            v = vs.split "\n"

            @headers[k] = if v.length > 0
              # Hack for node 0.2 headers
              # http://github.com/ry/node/commit/6560ab9
              v.join "\r\n#{k}: "
            else
              vs

          debug "response received: #{@statusCode}"

          # Emit response once we've received the status and headers
          @request.emit 'response', this

        # Else its body parts
        else if data.length > 0
          @emit 'data', data

      # Empty string means EOF
      else
        debug "response complete"

        assert.ok @statusCode, "Missing status code"
        assert.ok @headers, "Missing headers"

        @readable  = false
        @completed = true
        @emit 'end'

    catch error
      # See if payload is an exception backtrace
      exception = try JSON.parse data
      if exception and exception.name and exception.message
        error       = new Error exception.message
        error.name  = exception.name
        error.stack = exception.stack

      debug "response error", error

      @readable = false

      @socket.emit 'error', error
