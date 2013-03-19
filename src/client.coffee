assert = require 'assert'
fs     = require 'fs'
ns     = require 'netstring'
url    = require 'url'

{Socket} = require 'net'
{Stream} = require 'stream'
{debug}  = require './util'

{BufferedRequest} = require './util'

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
        request.pipe this
        request.flush()
    else
      # Try to reconnect and try again soon
      @reconnect()

  _finishRequest: ->
    debug "finishing request"

    req = @_outgoing.shift()
    req.destroy()

    res = @_incoming
    @_incoming = null

    if res is null or res.received is false
      req.emit 'error', new Error "Response was not received"
    else if res.readable and not res.statusCode
      req.emit 'error', new Error "Missing status code"
    else if res.readable and not res.headers
      req.emit 'error', new Error "Missing headers"

    # Anymore requests, continue processing
    if @_outgoing.length > 0
      @_processRequest()

  # Reconnect if the connection is closed.
  reconnect: ->
    if @readyState is 'closed' or @readyState is 'readOnly'
      debug "connecting to #{@port}"
      @connect @port, @host

  # Start the connection and create a ClientRequest.
  request: (args...) ->
    request = new ClientRequest args...
    @_outgoing.push request
    @_processRequest()
    request

# Public API for creating a **Client**
exports.createConnection = (port, host) ->
  client = new Client
  client.port = port
  client.host = host
  client

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
exports.ClientRequest = class ClientRequest extends BufferedRequest
  _buildEnv: ->
    env = {}

    env['REQUEST_METHOD'] = @method

    {pathname, query} = url.parse @url
    env['PATH_INFO']    = pathname
    env['QUERY_STRING'] = query ? ""
    env['SCRIPT_NAME']  = ""

    env['REMOTE_ADDR'] = "0.0.0.0"
    env['SERVER_ADDR'] = "0.0.0.0"

    if host = @headers.host
      parts = @headers.host.split ':'
      env['SERVER_NAME'] = parts[0]
      env['SERVER_PORT'] = parts[1]

    env['SERVER_NAME'] ?= "localhost"
    env['SERVER_PORT'] ?= "80"

    for key, value of @headers
      key = key.toUpperCase().replace /-/g, '_'
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      env[key] = value

    for key, value of @proxyMetaVariables
      env[key] = value

    env

  # Write chunk to client
  write: (chunk, encoding) ->
    super ns.nsWrite chunk, 0, chunk.length, null, 0, encoding

  # Closes writting socket.
  end: (chunk, encoding) ->
    if (chunk)
      @write chunk, encoding
    super ""

  flush: ->
    # Write Env header if queue hasn't been flushed
    if @_queue
      debug "requesting #{@method} #{@url}"
      chunk   = JSON.stringify @_buildEnv()
      nsChunk = ns.nsWrite chunk, 0, chunk.length, null, 0, 'utf8'
      debug "writing header #{nsChunk.length} bytes"
      @emit 'data', nsChunk

    super

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
    @writable    = true
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

          if @_path = @headers['X-Sendfile']
            delete @headers['X-Sendfile']

            fs.stat @_path, (err, stat) =>
              unless stat.isFile()
                err = new Error "#{@_path} is not a file"

              if err
                @onError err
              else
                @headers['Content-Length'] = "#{stat.size}"
                @headers['Last-Modified']  = "#{stat.mtime.toUTCString()}"

                @request.emit 'response', this

                fs.createReadStream(@_path).pipe this
          else
            # Emit response once we've received the status and headers
            @request.emit 'response', this

        # Else its body parts
        else if data.length > 0 and not @_path
          @write data

      # Empty string means EOF
      else if not @_path
        @end()

    catch error
      # See if payload is an exception backtrace
      exception = try JSON.parse data
      if exception and exception.name and exception.message
        error       = new Error exception.message
        error.name  = exception.name
        error.stack = exception.stack

      @onError error

  onError: (error) ->
    debug "response error", error

    @readable = false
    @socket.emit 'error', error

  write: (data) ->
    return if not @readable or @completed

    @emit 'data', data

  end: (data) ->
    return if not @readable or @completed

    @emit 'data', data if data

    assert.ok @statusCode, "Missing status code"
    assert.ok @headers, "Missing headers"

    debug "response complete"

    @readable  = false
    @completed = true

    @emit 'end'

  pipe: (dest, options) ->
    # Detect when we are piping to another HttpResponse and copy over headers
    if dest.writeHead
      # Don't enable chunked encoding
      dest.useChunkedEncodingByDefault = false

      dest.writeHead @statusCode, @headers

      # Force chunkedEncoding off and pass through whatever data comes from the client
      dest.chunkedEncoding = false

    super
