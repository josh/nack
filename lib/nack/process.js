var client = require('nack/client');
var spawn  = require('child_process').spawn;

function tmpSock () {
  var pid  = process.pid;
  var rand = Math.floor(Math.random() * 10000000000);
  return "/tmp/nack." + pid + "." + rand + ".sock";
}

var Process = function (config) {
  this.sock  = tmpSock();
  this.child = spawn("nackup", ['--file', this.sock, config]);

  this.child.on('exit', function (code, signal) {
    this.sock  = null;
    this.child = null;

    if (this.onexit)
      this.onexit();
  }.bind(this));

  return this;
}
exports.Process = Process;

Process.prototype.proxyRequest = function (req, res) {
  var sock = client.createConnection(this.sock);
  sock.proxyRequest(req, res);
}

Process.prototype.quit = function (callback) {
  this.child.kill('SIGQUIT');
  this.onexit = callback;
}

exports.createProcess = function (config) {
  return new Process(config);
}
