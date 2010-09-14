var client = require('nack/client');
var spawn  = require('child_process').spawn;

var nackup = __dirname + "/../../bin/nackup";

var Process = function (config) {
  // TODO: Create a new sock for each server
  this.sock = __dirname + "/../../test/nack.sock";

  spawn(nackup, ['--file', this.sock, config]);

  return this;
}
exports.Process = Process;

Process.prototype.proxyRequest = function (req, res) {
  var sock = client.createConnection(this.sock);
  sock.proxyRequest(req, res);
}

exports.createProcess = function (config) {
  return new Process(config);
}
