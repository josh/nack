sys = require 'sys'
url = require 'url'
ns  = require './ns'

{Stream}              = require 'net'
{EventEmitter}        = require 'events'
{BufferedWriteStream} = require './buffered'

# A **ClientRequest** is returned when `Client.request()` is called.
#
# It is a Writable Stream and responds to the conventional
# `write` and `end` methods.
#
# Its also an EventEmitter with the following events:
#
#   Event 'response'
#   function (response) { }
#   Emitted when a response is received to this request. This event is
#   emitted only once. The response argument will be an instance of
#   `ClientResponse`.
#
exports.ClientRequest = class ClientRequest extends EventEmitter
  constructor: (@socket, @method, @path, headers, metaVariables) ->
    # Write `@socket` with `BufferedWriteStream` so we can write to it
    # before it is ready.
    @bufferedSocket = new BufferedWriteStream @socket
    @writeable = true

    # Build an `@env` obj from headers and metaVariables
    @_parseEnv headers, metaVariables
    # Then write it to the socket
    @write JSON.stringify @env

    # Flush the buffer once we've established a connection to the server
    @socket.on 'connect', => @bufferedSocket.flush()

    # Prepare `ClientResponse`
    response = new ClientResponse @socket
    response._initParser () =>
      @emit 'response', response

  _parseEnv: (headers, metaVariables) ->
    @env = {}

    # Set REQUEST_METHOD
    @env['REQUEST_METHOD'] = @method

    # Parse the request path an assign its parts to the env
    {pathname, query} = url.parse @path
    @env['PATH_INFO']    = pathname
    @env['QUERY_STRING'] = query
    @env['SCRIPT_NAME']  = ""

    # Initialize REMOTE_ADDR and SERVER_ADDR to "0.0.0.0"
    # They can be overridden by `metaVariables`
    @env['REMOTE_ADDR'] = "0.0.0.0"
    @env['SERVER_ADDR'] = "0.0.0.0"

    # Parse the HTTP_HOST header and set SERVER_NAME and SERVER_PORT
    if host = headers.host
      if {name, port} = headers.host.split ':'
        @env['SERVER_NAME'] = name
        @env['SERVER_PORT'] = port

    for key, value of headers
      # Upcase all header key values
      key = key.toUpperCase().replace('-', '_')
      # Prepend HTTP_ to them
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      # And merge them into the `@env` obj
      @env[key] = value

    # Merge all `metaVariables` into the `@env` obj
    for key, value of metaVariables
      @env[key] = value

  # Write chunk to client
  write: (chunk) ->
    # Netstring encode the chunk and write it to the socket
    @bufferedSocket.write ns.nsWrite(chunk.toString())

  # Closes writting socket.
  end: ->
    @bufferedSocket.end()

# A **ClientResponse** is emitted from the client request's
# `response` event.
#
# It is a Readable Stream and emits the conventional events:
#
#   Event: `data`
#   function (chunk) { }
#   Emitted when a piece of the message body is received.
#
#   Event: `end`
#   function () { }
#   Emitted exactly once for each message. No arguments. After emitted
#   no other events will be emitted on the request.
#
#    Event: 'error'
#    function (exception) { }
#    Emitted when an error occurs.
#
exports.ClientResponse = class ClientResponse extends EventEmitter
  constructor: (@socket) ->
    @client = @socket
    @statusCode = null
    @headers = null
    @_stopped = false

  _initParser: (callback) ->
    # Initialize a Netstring stream parser
    nsStream = new ns.Stream @socket

    nsStream.on 'data', (data) =>
      return if @_stopped
      @_parseData data, callback

    nsStream.on 'error', (exception) =>
      return if @_stopped
      # Flag the response as stopped
      @_stopped = true
      # Bubble the error, hopefully someone will catch it
      @socket.emit 'error', exception

    @socket.on 'end', =>
      @emit 'end'

  _parseData: (data, callback) ->
    try
      # The first response part is the status
      if !@statusCode
        @statusCode = JSON.parse(data)
      # The second part is the JSON encoded headers
      else if !@headers
        @headers = []
        # Parse the headers
        for k, vs of JSON.parse(data)
          # Split multiline Rack headers and create an array
          for v in vs.split "\n"
            @headers.push [k, v]
      # Else its body parts
      else
        chunk = data

      # Call the callback once we've received the status and headers
      if @statusCode? && @headers? && !chunk?
        callback()
      else if chunk?
        # Emit data chunks
        @emit 'data', chunk
    catch error
      # Flag the response as stopped
      @_stopped = true
      # Catch and emit as a socket error
      @socket.emit 'error', error

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
  # Reconnect if the connection is closed.
  reconnect: ->
    if @readyState is 'closed'
      @connect @port, @host

  # Start the connection and create a ClientRequest.
  request: (args...) ->
    @reconnect()
    request = new ClientRequest @, args...
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

# Public API for creating a **Client**
exports.createConnection = (port, host) ->
  client = new Client
  client.port = port
  client.host = host
  client
