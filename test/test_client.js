require.paths.unshift(__dirname + "/../lib");

var http   = require('http');
var client = require('nack/client');

var sock = __dirname + "/nack.sock";

http.createServer(function (req, res) {
  client.request(sock, req, res);
}).listen(8124, "127.0.0.1");
