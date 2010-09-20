(function() {
  var BufferedReadStream, EventEmitter, Process, _a, _b, _c, client, spawn, sys, tmpSock;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __slice = Array.prototype.slice, __extends = function(child, parent) {
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
  _c = require('nack/buffered');
  BufferedReadStream = _c.BufferedReadStream;
  tmpSock = function() {
    var pid, rand;
    pid = process.pid;
    rand = Math.floor(Math.random() * 10000000000);
    return "/tmp/nack." + pid + "." + rand + ".sock";
  };
  exports.Process = (function() {
    Process = function(_d, options) {
      this.config = _d;
      options = (typeof options !== "undefined" && options !== null) ? options : {};
      this.idle = options.idle;
      this.state = null;
      return this;
    };
    __extends(Process, EventEmitter);
    Process.prototype.spawn = function() {
      var ready;
      if (this.state) {
        return null;
      }
      this.state = 'spawning';
      this.sockPath = tmpSock();
      this.child = spawn("nackup", ['--file', this.sockPath, this.config]);
      this.stdout = this.child.stdout;
      this.stderr = this.child.stderr;
      ready = __bind(function() {
        if (!this.ready) {
          this.state = 'ready';
          return this.emit('ready');
        }
      }, this);
      this.stdout.on('data', ready);
      this.stderr.on('data', ready);
      this.child.on('exit', __bind(function(code, signal) {
        this.clearTimeout();
        this.state = (this.sockPath = (this.child = null));
        this.stdout = (this.stderr = null);
        return this.emit('exit');
      }, this));
      this.on('ready', __bind(function() {
        return this.deferTimeout();
      }, this));
      this.emit('spawn');
      return this;
    };
    Process.prototype.onNext = function(event, listener) {
      var callback;
      callback = __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        this.removeListener(event, callback);
        return listener.apply(this, args);
      }, this);
      return this.on(event, callback);
    };
    Process.prototype.whenReady = function(callback) {
      if (this.child && this.state === 'ready') {
        return callback();
      } else {
        this.spawn();
        return this.onNext('ready', callback);
      }
    };
    Process.prototype.clearTimeout = function() {
      return this._timeoutId ? clearTimeout(this._timeoutId) : null;
    };
    Process.prototype.deferTimeout = function() {
      var callback;
      if (this.idle) {
        this.clearTimeout();
        callback = __bind(function() {
          this.emit('idle');
          return this.quit();
        }, this);
        return (this._timeoutId = setTimeout(callback, this.idle));
      }
    };
    Process.prototype.proxyRequest = function(req, res, callback) {
      var reqBuf;
      this.deferTimeout();
      reqBuf = new BufferedReadStream(req);
      return this.whenReady(__bind(function() {
        var connection;
        connection = client.createConnection(this.sockPath);
        connection.proxyRequest(reqBuf, res, callback);
        return reqBuf.flush();
      }, this));
    };
    Process.prototype.quit = function() {
      return this.child ? this.child.kill('SIGQUIT') : null;
    };
    return Process;
  })();
  exports.createProcess = function() {
    var _d, _e, _f, args;
    args = __slice.call(arguments, 0);
    return (function() {
      var ctor = function(){};
      __extends(ctor, _d = Process);
      return typeof (_e = _d.apply(_f = new ctor, args)) === "object" ? _e : _f;
    }).call(this);
  };
})();
