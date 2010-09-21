sys = require 'sys'
url = require 'url'

{Stream}              = require 'net'
{EventEmitter}        = require 'events'
{BufferedWriteStream} = require 'nack/buffered'
{StreamParser}        = require 'nack/json'

CRLF = "\r\n"

exports.ClientRequest = class ClientRequest extends EventEmitter
  constructor: (@socket, @method, @path, headers) ->
    @bufferedSocket = new BufferedWriteStream @socket
    @writeable = true

    @_parseHeaders headers
    @writeObj @headers

    @socket.on 'connect', => @bufferedSocket.flush()

    @bufferedSocket.on 'drain', => @emit 'drain'
    @bufferedSocket.on 'close', => @emit 'close'

    @_initParser()

  _parseHeaders: (headers) ->
    @headers = {}
    @headers["REQUEST_METHOD"] = @method

    {pathname, query} = url.parse @path
    @headers["PATH_INFO"]    = pathname
    @headers["QUERY_STRING"] = query
    @headers["SCRIPT_NAME"]  = ""

    for key, value of headers
      key = key.toUpperCase().replace('-', '_')
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      @headers[key] = value

  _initParser: ->
    response     = new ClientResponse @socket
    streamParser = new StreamParser @socket

    streamParser.on "obj", (obj) =>
      if !response.statusCode
        response.statusCode = obj
      else if !response.headers
        response.headers = obj
      else
        chunk = obj

      if response.statusCode? && response.headers? && !chunk?
        @emit 'response', response
      else if chunk?
        response.emit 'data', chunk

    @socket.on 'end', ->
      response.emit 'end'

  writeObj: (obj) ->
    @bufferedSocket.write JSON.stringify(obj)
    @bufferedSocket.write CRLF

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

  request: (method, path, headers) ->
    @reconnect()
    request = new ClientRequest @, method, path, headers
    request

  proxyRequest: (serverRequest, serverResponse, callback) ->
    clientRequest = @request serverRequest.method, serverRequest.url, serverRequest.headers
    sys.pump serverRequest, clientRequest

    clientRequest.on "response", (clientResponse) ->
      serverResponse.writeHead clientResponse.statusCode, clientResponse.headers
      sys.pump clientResponse, serverResponse, callback

      if callback?
        clientResponse.on "end", callback

exports.createConnection = (port, host) ->
  client = new Client
  client.port = port
  client.host = host
  client
