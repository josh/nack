require.paths.unshift(__dirname + "/../lib");

var http    = require('http');
var process = require('nack/process');

var app = process.createProcess(__dirname + "/config.ru");

http.createServer(function (req, res) {
  app.proxyRequest(req, res);
}).listen(8124, "127.0.0.1");
