net        = require 'net'
url        = require 'url'
jsonParser = require 'nack/json_parser'

{EventEmitter} = require 'events'

CRLF = "\r\n"

exports.ClientRequest = class ClientRequest extends EventEmitter
  constructor: (@socket, method, path, headers) ->
    @connected = false
    @ended     = false

    @headers = @parseRequest method, path, headers

    @buffer = []
    @buffer.push new Buffer(JSON.stringify(@headers))
    @buffer.push new Buffer(CRLF)

    @connect()

  parseRequest: (method, path, request_headers) ->
    headers = {}

    headers["REQUEST_METHOD"] = method

    {pathname, query} = url.parse path
    headers["PATH_INFO"]    = pathname
    headers["QUERY_STRING"] = query
    headers["SCRIPT_NAME"]  = ""

    for key, value of request_headers
      key = key.toUpperCase().replace('-', '_')
      key = "HTTP_#{key}" unless key == 'CONTENT_TYPE' or key == 'CONTENT_LENGTH'
      headers[key] = value

    headers

  connect: () ->
    @socket.setEncoding "utf8"

    @socket.addListener "connect", () =>
      @connected = true
      @flush()
      @socket.end() if @ended

    response = new ClientResponse @socket
    stream   = new jsonParser.Stream @socket

    stream.addListener "obj", (obj) =>
      if !response.statusCode
        response.statusCode = obj
      else if !response.headers
        response.headers = obj
      else
        chunk = obj

      if response.statusCode? && response.headers? && !chunk?
        @emit "response", response
      else if chunk?
        response.emit "data", chunk

    @socket.addListener "end", () ->
      response.emit "end"

  flush: () ->
    if @connected
      while @buffer.length > 0
        @socket.write @buffer.shift()

  write: (chunk) ->
    @buffer.push new Buffer(JSON.stringify(chunk))
    @buffer.push new Buffer(CRLF)
    @flush()

  end: ->
    @ended = true

    if @connected
      @flush()
      @socket.end()

exports.ClientResponse = class ClientResponse extends EventEmitter
  constructor: (@socket) ->
    @statusCode = null
    @headers = null

exports.Client = class Client
  connect: (port, host) ->
    @socket = net.createConnection port, host

  request: (method, path, headers) ->
    request = new ClientRequest(@socket, method, path, headers)
    request.connect
    request

  proxyRequest: (req, res) ->
    clientRequest = @request req.method, req.url, req.headers

    req.addListener "data", (chunk) =>
      clientRequest.write chunk

    req.addListener "end", (chunk) =>
      clientRequest.end()

    clientRequest.on "response", (clientResponse) ->
      res.writeHead clientResponse.statusCode, clientResponse.headers

      clientResponse.on "data", (chunk) ->
        res.write chunk

      clientResponse.addListener "end", () ->
        res.end()

exports.createConnection = (port, host) ->
  client = new Client()
  client.connect port, host
  client
