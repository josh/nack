require.paths.unshift(__dirname + "/../lib");
process.env['PATH'] = __dirname + "/../bin:" + process.env['PATH']

var http = require('http');
var proc = require('nack/process');

var app = proc.createProcess(__dirname + "/config.ru");

http.createServer(function (req, res) {
  app.proxyRequest(req, res);
}).listen(8124, "127.0.0.1");
