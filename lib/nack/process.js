(function() {
  var Process, _a, client, spawn, sys, tmpSock;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  };
  sys = require('sys');
  client = require('nack/client');
  _a = require('child_process');
  spawn = _a.spawn;
  tmpSock = function() {
    var pid, rand;
    pid = process.pid;
    rand = Math.floor(Math.random() * 10000000000);
    return "/tmp/nack." + pid + "." + rand + ".sock";
  };
  Process = function(config) {
    this.sock = tmpSock();
    this.child = spawn("nackup", ['--file', this.sock, config]);
    this.child.stdout.on('data', function(data) {
      return sys.log(config + ': ' + data);
    });
    this.child.stderr.on('data', function(data) {
      return sys.log(config + ': ' + data);
    });
    this.child.on('exit', __bind(function(code, signal) {
      this.sock = null;
      this.child = null;
      if (this.onexit) {
        return this.onexit();
      }
    }, this));
    return this;
  };
  Process.prototype.proxyRequest = function(req, res) {
    var sock;
    sock = client.createConnection(this.sock);
    return sock.proxyRequest(req, res);
  };
  Process.prototype.quit = function(callback) {
    this.child.kill('SIGQUIT');
    return (this.onexit = callback);
  };
  exports.Process = Process;
  exports.createProcess = function(config) {
    return new Process(config);
  };
})();
