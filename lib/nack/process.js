var client = require('nack/client');
var spawn  = require('child_process').spawn;

var nackup = __dirname + "/../../bin/nackup";

function tmpSock () {
  var pid  = process.pid;
  var rand = Math.floor(Math.random() * 10000000000);
  return "/tmp/nack." + pid + "." + rand + ".sock";
}

var Process = function (config) {
  this.sock = tmpSock();
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
