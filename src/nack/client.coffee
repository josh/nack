net        = require 'net'
jsonParser = require 'nack/json_parser'

CRLF = "\r\n"

class Client
  connect: (port, host) ->
    @socket = net.createConnection port, host

  proxyRequest: (req, res) ->
    @socket.setEncoding "utf8"

    @socket.addListener "connect", () =>
      @socket.write JSON.stringify(req.headers)
      @socket.write CRLF

      @socket.end()

      # req.addListener "data", (chunk) =>
      #   @socket.write JSON.stringify(chunk)
      #   @socket.write CRLF

      # req.addListener "end", (chunk) =>
      #   @socket.end()

    jsonStream = new jsonParser.Stream @socket

    [status, headers, part] = [null, null, null]
    jsonStream.addListener "obj", (obj) ->
      if !status?
        status = obj
      else if !headers?
        headers = obj
      else
        part = obj

      if status? && headers? && !part?
        res.writeHead status, headers
      else if part?
        res.write part

    @socket.addListener "end", (obj) ->
      res.end()

exports.Client = Client

exports.createConnection = (port, host) ->
  client = new Client()
  client.connect port, host
  client
