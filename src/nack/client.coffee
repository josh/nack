sys = require 'sys'
url = require 'url'
ns  = require './ns'

{Stream}       = require 'net'
{EventEmitter} = require 'events'

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
exports.Client = class Client extends Stream
  constructor: ->
    @_outgoing = []
    @_incoming = null

    @on 'connect', => @_processRequest()
    @on 'close',   => @_finishRequest()

    @_initResponseParser()

  _initResponseParser: () ->
    # Initialize a Netstring stream parser
    nsStream = new ns.Stream @

    nsStream.on 'data', (data) =>
      if @_incoming
        @_incoming._receiveData data

    nsStream.on 'error', (exception) =>
      @_incoming = null
      @emit 'error', exception

  _processRequest: () ->
    if @readyState is 'open' and !@_incoming
      if request = @_outgoing[0]
        @_incoming = new ClientResponse @, request
        request.flush()
    else
      @reconnect()

  _finishRequest: () ->
    @_outgoing.shift()
    @_incoming = null

    if @_outgoing.length > 0
      @_processRequest()

  # Reconnect if the connection is closed.
  reconnect: ->
    if @readyState is 'closed'
      @connect @port, @host

  # Start the connection and create a ClientRequest.
  request: (args...) ->
    request = new ClientRequest @, args...
    @_outgoing.push request
    @_processRequest()
    request

  # Proxy a `http.ServerRequest` and `http.serverResponse` between
  # the `Client`.
  proxyRequest: (serverRequest, serverResponse) ->
    metaVariables =
      "REMOTE_ADDR": serverRequest.connection.remoteAddress
      "REMOTE_PORT": serverRequest.connection.remotePort

    clientRequest = @request serverRequest.method, serverRequest.url, serverRequest.headers, metaVariables
    sys.pump serverRequest, clientRequest

    clientRequest.on "response", (clientResponse) ->
      serverResponse.writeHead clientResponse.statusCode, clientResponse.headers
      sys.pump clientResponse, serverResponse

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
#
exports.ClientRequest = class ClientRequest extends EventEmitter
  constructor: (@socket, @method, @path, headers, metaVariables) ->
    @writeable = true

    # Initialize writeQueue since socket is still connecting
    # net.Stream will buffer on connecting in node 0.3.x
    @_writeQueue = []

    # Build an `@env` obj from headers and metaVariables
    @_parseEnv headers, metaVariables
    # Then write it to the socket
    @write JSON.stringify @env

  _parseEnv: (headers, metaVariables) ->
    @env = {}

    # Set `REQUEST_METHOD`
    @env['REQUEST_METHOD'] = @method

    # Parse the request path an assign its parts to the env
    {pathname, query} = url.parse @path
    @env['PATH_INFO']    = pathname
    @env['QUERY_STRING'] = query
    @env['SCRIPT_NAME']  = ""

    # Initialize `REMOTE_ADDR` and `SERVER_ADDR` to "0.0.0.0"
    # They can be overridden by `metaVariables`
    @env['REMOTE_ADDR'] = "0.0.0.0"
    @env['SERVER_ADDR'] = "0.0.0.0"

    # Parse the `HTTP_HOST` header and set `SERVER_NAME` and `SERVER_PORT`
    if host = headers.host
      if {name, port} = headers.host.split ':'
        @env['SERVER_NAME'] = name
        @env['SERVER_PORT'] = port

    for key, value of headers
      # Upcase all header key values
      key = key.toUpperCase().replace('-', '_')
      # Prepend `HTTP_` to them
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      # And merge them into the `@env` obj
      @env[key] = value

    # Merge all `metaVariables` into the `@env` obj
    for key, value of metaVariables
      @env[key] = value

  # Write chunk to client
  write: (chunk) ->
    # Netstring encode chunk
    nsChunk = ns.nsWrite chunk.toString()

    if @_writeQueue
      @_writeQueue.push nsChunk
      # Return false because data was buffered
      false
    else
      @socket.write nsChunk

  # Closes writting socket.
  end: (chunk) ->
    if (chunk)
      @write chunk

    flushed = if @_writeQueue
      @_writeQueue.push END_OF_FILE
      # Return false because data was buffered
      false
    else
      @socket.end END_OF_FILE

    # Mark stream as closed
    @writeable = false

    flushed

  destroy: ->
    @socket.destroy()

  flush: ->
    while @_writeQueue and @_writeQueue.length
      data = @_writeQueue.shift()

      if data is END_OF_FILE
        @socket.end data
      else
        @socket.write data

    @_writeQueue = null

    # Buffer is empty, let the world know!
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
exports.ClientResponse = class ClientResponse extends EventEmitter
  constructor: (@socket, @request) ->
    @client = @socket
    @statusCode = null
    @headers = null

  _receiveData: (data) ->
    try
      # The first response part is the status
      if !@statusCode
        @statusCode = JSON.parse data
      # The second part is the JSON encoded headers
      else if !@headers
        @headers = {}
        # Parse the headers
        for k, vs of JSON.parse data
          # Split multiline Rack headers
          v = vs.split "\n"
          @headers[k] = if v.length > 0
            # Hack for node 0.2 headers
            # http://github.com/ry/node/commit/6560ab9
            v.join "\r\n#{k}: "
          else
            vs

        # Emit response once we've received the status and headers
        @request.emit 'response', @

      # Else its body parts
      else if data.length > 0
        @emit 'data', data
      else
        @emit 'end'

    catch error
      # Catch and emit as a socket error
      @socket.emit 'error', error
