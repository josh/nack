(function() {
  var EventEmitter, Process, _a, _b, client, spawn, sys, tmpSock;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  };
  sys = require('sys');
  client = require('nack/client');
  _a = require('child_process');
  spawn = _a.spawn;
  _b = require('events');
  EventEmitter = _b.EventEmitter;
  tmpSock = function() {
    var pid, rand;
    pid = process.pid;
    rand = Math.floor(Math.random() * 10000000000);
    return "/tmp/nack." + pid + "." + rand + ".sock";
  };
  exports.Process = (function() {
    Process = function(_c) {
      this.config = _c;
      this.state = null;
      return this;
    };
    __extends(Process, EventEmitter);
    Process.prototype.spawn = function() {
      var log;
      if (this.state) {
        return null;
      }
      this.state = 'spawning';
      this.sockPath = tmpSock();
      this.child = spawn("nackup", ['--file', this.sockPath, this.config]);
      log = __bind(function(message) {
        return sys.log(this.config + ': ' + message);
      }, this);
      this.child.stdout.on('data', __bind(function(data) {
        return log(data);
      }, this));
      this.child.stderr.on('data', __bind(function(data) {
        if (!this.ready && data.toString() === "ready\n") {
          this.state = 'ready';
          return this.emit('ready');
        } else {
          return log(data);
        }
      }, this));
      return this.child.on('exit', __bind(function(code, signal) {
        this.state = (this.sockPath = (this.child = null));
        return this.emit('exit');
      }, this));
    };
    Process.prototype.whenReady = function(callback) {
      if (this.child && this.state === 'ready') {
        return callback();
      } else {
        this.spawn();
        return this.on('ready', callback);
      }
    };
    Process.prototype.proxyRequest = function(req, res, callback) {
      return this.whenReady(__bind(function() {
        var connection;
        connection = client.createConnection(this.sockPath);
        return connection.proxyRequest(req, res, callback);
      }, this));
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
