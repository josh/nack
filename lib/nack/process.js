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
  exports.Process = (function() {
    Process = function(_b) {
      var log, setReady;
      this.config = _b;
      this.state = null;
      this.listeners = {};
      this.sock = tmpSock();
      this.child = spawn("nackup", ['--file', this.sock, this.config]);
      log = __bind(function(message) {
        return sys.log(this.config + ': ' + message);
      }, this);
      setReady = __bind(function() {
        var onready;
        this.state = 'ready';
        return (onready = this.listeners['ready']) ? onready(this) : null;
      }, this);
      this.child.stdout.on('data', __bind(function(data) {
        return log(data);
      }, this));
      this.child.stderr.on('data', __bind(function(data) {
        return !this.ready && data.toString() === "ready\n" ? setReady() : log(data);
      }, this));
      this.child.on('exit', __bind(function(code, signal) {
        var onexit;
        this.sock = null;
        this.child = null;
        return (onexit = this.listeners['exit']) ? onexit() : null;
      }, this));
      return this;
    };
    Process.prototype.on = function(event, callback) {
      return (this.listeners[event] = callback);
    };
    Process.prototype.proxyRequest = function(req, res) {
      var sock;
      sock = client.createConnection(this.sock);
      return sock.proxyRequest(req, res);
    };
    Process.prototype.quit = function() {
      return this.child.kill('SIGQUIT');
    };
    return Process;
  })();
  exports.createProcess = function(config) {
    return new Process(config);
  };
})();
