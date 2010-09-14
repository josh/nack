var net        = require('net');
var jsonParser = require('nack/json_parser');

var crlf = "\r\n";

var Client = function () {
  this.socket = null;
  return this;
}
exports.Client = Client;

Client.prototype.connect = function (port, host) {
  this.socket = net.createConnection(port, host);
}

Client.prototype.proxyRequest = function (req, res) {
  var socket = this.socket;

  socket.setEncoding("utf8");

  socket.addListener("connect", function () {
    socket.write(JSON.stringify(req.headers));
    socket.write(crlf);

    socket.end();

    // req.addListener("data", function (chunk) {
    //   socket.write(JSON.stringify(chunk));
    //   socket.write(crlf);
    // });

    // req.addListener("end", function (chunk) {
    //   socket.end();
    // });
  });

  var jsonStream = new jsonParser.Stream(socket);

  var status, headers, part;
  jsonStream.addListener("obj", function (obj) {
    if (status == null)
      status = obj
    else if (headers == null)
      headers = obj
    else
      part = obj

    if (status && headers && part == null)
      res.writeHead(status, headers);
    else if (part)
      res.write(part);
  });

  socket.addListener("end", function (obj) {
    res.end();
  });
}

exports.createConnection = function (port, host) {
  var client = new Client();
  client.connect(port, host);
  return client;
}
