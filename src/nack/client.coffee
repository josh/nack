url = require 'url'

{Stream}         = require 'net'
{EventEmitter}   = require 'events'
{BufferedStream} = require 'nack/buffered_stream'
{StreamParser}   = require 'nack/json'

CRLF = "\r\n"

exports.ClientRequest = class ClientRequest extends BufferedStream
  constructor: (@socket, @method, @path, headers) ->
    super @socket

    @_parseHeaders headers
    @write @headers

    @socket.on 'connect', () => @flush()

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

  _initParser: () ->
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

    @socket.on 'end', () ->
      response.emit 'end'

  write: (chunk) ->
    super new Buffer(JSON.stringify(chunk))
    super new Buffer(CRLF)

exports.ClientResponse = class ClientResponse extends EventEmitter
  constructor: (@socket) ->
    @client = @socket
    @statusCode = null
    @headers = null

exports.Client = class Client extends Stream
  reconnect: () ->
    if @readyState is 'closed'
      @connect @port, @host

  request: (method, path, headers) ->
    @reconnect()
    request = new ClientRequest @, method, path, headers
    request

  proxyRequest: (req, res) ->
    clientRequest = @request req.method, req.url, req.headers

    req.on "data", (chunk) =>
      clientRequest.write chunk

    req.on "end", (chunk) =>
      clientRequest.end()

    clientRequest.on "response", (clientResponse) ->
      res.writeHead clientResponse.statusCode, clientResponse.headers

      clientResponse.on "data", (chunk) ->
        res.write chunk

      clientResponse.on "end", () ->
        res.end()

exports.createConnection = (port, host) ->
  client = new Client
  client.port = port
  client.host = host
  client
