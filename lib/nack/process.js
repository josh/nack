(function() {
  var BufferedReadStream, EventEmitter, Process, _ref, client, exec, exists, spawn, sys, tmpSock;
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
  _ref = require('child_process');
  spawn = _ref.spawn;
  exec = _ref.exec;
  _ref = require('path');
  exists = _ref.exists;
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  _ref = require('nack/buffered');
  BufferedReadStream = _ref.BufferedReadStream;
  tmpSock = function() {
    var pid, rand;
    pid = process.pid;
    rand = Math.floor(Math.random() * 10000000000);
    return "/tmp/nack." + pid + "." + rand + ".sock";
  };
  exports.Process = (function() {
    Process = function(_arg, options) {
      var _ref2, raiseConfigError;
      this.config = _arg;
      options = (typeof options !== "undefined" && options !== null) ? options : {};
      this.idle = options.idle;
      this.state = null;
      raiseConfigError = __bind(function() {
        return this.emit('error', new Error("configuration \"" + (this.config) + "\" doesn't exist"));
      }, this);
      if (typeof (_ref2 = this.config) !== "undefined" && _ref2 !== null) {
        exists(this.config, __bind(function(ok) {
          if (!ok) {
            return raiseConfigError();
          }
        }, this));
      } else {
        raiseConfigError();
      }
      return this;
    };
    __extends(Process, EventEmitter);
    Process.prototype.getNackupPath = function(callback) {
      var _ref2;
      return (typeof (_ref2 = this.nackupPath) !== "undefined" && _ref2 !== null) ? callback(null, this.nackupPath) : exec('which nackup', __bind(function(error, stdout, stderr) {
        if (error) {
          return callback(new Error("Couldn't find `nackup` in PATH"));
        } else {
          this.nackupPath = stdout.replace(/(\n|\r)+$/, '');
          return callback(error, this.nackupPath);
        }
      }, this));
    };
    Process.prototype.spawn = function() {
      if (this.state) {
        return null;
      }
      this.changeState('spawning');
      this.getNackupPath(__bind(function(err, nackup) {
        var ready;
        if (err) {
          return this.emit('error', err);
        }
        this.sockPath = tmpSock();
        this.child = spawn("nackup", ['--file', this.sockPath, this.config]);
        this.stdout = this.child.stdout;
        this.stderr = this.child.stderr;
        ready = __bind(function(data) {
          if (data.toString() === "ready\n") {
            this.stdout.removeListener('data', ready);
            this.stderr.removeListener('data', ready);
            return this.changeState('ready');
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
        return this.emit('spawn');
      }, this));
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
    Process.prototype.changeState = function(state) {
      if (this.state !== state) {
        this.state = state;
        return process.nextTick(__bind(function() {
          return this.emit(state);
        }, this));
      }
    };
    Process.prototype.onState = function(state, callback) {
      return this.state === state ? callback() : this.onNext(state, __bind(function() {
        return this.onState(state, callback);
      }, this));
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
      this.spawn();
      return this.onState('ready', __bind(function() {
        var connection;
        if (this.state !== 'ready') {
          this.emit('error', new Error("process said it was ready but wasn't"));
        }
        this.changeState('busy');
        connection = client.createConnection(this.sockPath);
        connection.proxyRequest(reqBuf, res, __bind(function() {
          if (callback) {
            callback();
          }
          return this.changeState('ready');
        }, this));
        return reqBuf.flush();
      }, this));
    };
    Process.prototype.quit = function() {
      return this.child ? this.child.kill('SIGQUIT') : process.nextTick(__bind(function() {
        return this.emit('exit');
      }, this));
    };
    return Process;
  })();
  exports.createProcess = function() {
    var _ctor, _ref2, _result, args;
    args = __slice.call(arguments, 0);
    return (function() {
      var ctor = function(){};
      __extends(ctor, _ctor = Process);
      return typeof (_result = _ctor.apply(_ref2 = new ctor, args)) === "object" ? _result : _ref2;
    }).call(this);
  };
}).call(this);
