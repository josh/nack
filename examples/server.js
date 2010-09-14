// ./bin/nackup -f test/nack.sock examples/config.ru

require.paths.unshift(__dirname + "/../lib");

var http   = require('http');
var server = require('nack/server');

var app = server.createServer(__dirname + "/config.ru");

http.createServer(function (req, res) {
  app.request(req, res);
}).listen(8124, "127.0.0.1");
