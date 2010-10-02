sys = require 'sys'
url = require 'url'
ns  = require 'nack/ns'

{Stream}              = require 'net'
{EventEmitter}        = require 'events'
{BufferedWriteStream} = require 'nack/buffered'

exports.ClientRequest = class ClientRequest extends EventEmitter
  constructor: (@socket, @method, @path, headers, metaVariables) ->
    @bufferedSocket = new BufferedWriteStream @socket
    @writeable = true

    @_parseEnv headers, metaVariables
    @writeObj @env

    @socket.on 'connect', => @bufferedSocket.flush()

    @bufferedSocket.on 'drain', => @emit 'drain'
    @bufferedSocket.on 'close', => @emit 'close'

    @_initParser()

  _parseEnv: (headers, metaVariables) ->
    @env = {}
    @env['REQUEST_METHOD'] = @method

    {pathname, query} = url.parse @path
    @env['PATH_INFO']    = pathname
    @env['QUERY_STRING'] = query
    @env['SCRIPT_NAME']  = ""

    @env['REMOTE_ADDR'] = "0.0.0.0"
    @env['SERVER_ADDR'] = "0.0.0.0"

    if host = headers.host
      if {name, port} = headers.host.split ':'
        @env['SERVER_NAME'] = name
        @env['SERVER_PORT'] = port

    for key, value of headers
      key = key.toUpperCase().replace('-', '_')
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      @env[key] = value

    for key, value of metaVariables
      @env[key] = value

  _initParser: ->
    response = new ClientResponse @socket
    nsStream = new ns.Stream @socket

    nsStream.on 'data', (data) =>
      if !response.statusCode
        response.statusCode = JSON.parse(data)
      else if !response.headers
        response.headers = []
        for k, vs of JSON.parse(data)
          for v in vs.split "\n"
            response.headers.push [k, v]
      else
        chunk = data

      if response.statusCode? && response.headers? && !chunk?
        @emit 'response', response
      else if chunk?
        response.emit 'data', chunk

    nsStream.on 'error', (exception) =>
      @stream.emit 'error', exception

    @socket.on 'end', ->
      response.emit 'end'

  writeObj: (obj) ->
    @bufferedSocket.write ns.nsWrite(JSON.stringify(obj))

  write: (chunk) ->
    @writeObj chunk.toString()

  end: ->
    @bufferedSocket.end()

exports.ClientResponse = class ClientResponse extends EventEmitter
  constructor: (@socket) ->
    @client = @socket
    @statusCode = null
    @headers = null

exports.Client = class Client extends Stream
  reconnect: ->
    if @readyState is 'closed'
      @connect @port, @host

  request: (args...) ->
    @reconnect()
    request = new ClientRequest @, args...
    request

  proxyRequest: (serverRequest, serverResponse, callback) ->
    metaVariables =
      "REMOTE_ADDR": serverRequest.connection.remoteAddress
      "REMOTE_PORT": serverRequest.connection.remotePort

    clientRequest = @request serverRequest.method, serverRequest.url, serverRequest.headers, metaVariables
    sys.pump serverRequest, clientRequest

    @on "error", (err) ->
      callback err

    clientRequest.on "response", (clientResponse) ->
      serverResponse.writeHead clientResponse.statusCode, clientResponse.headers
      sys.pump clientResponse, serverResponse

      if callback?
        clientResponse.on "end", callback

exports.createConnection = (port, host) ->
  client = new Client
  client.port = port
  client.host = host
  client
