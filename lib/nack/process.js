(function() {
  var EventEmitter, LineBuffer, Process, Stream, client, exec, exists, fs, isFunction, onceFileExists, packageBin, packageLib, pause, spawn, tmpFile, tryConnect, _ref, _ref2;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  client = require('./client');
  fs = require('fs');
  exists = require('path').exists;
  _ref = require('./util'), pause = _ref.pause, isFunction = _ref.isFunction;
  LineBuffer = require('./util').LineBuffer;
  _ref2 = require('child_process'), spawn = _ref2.spawn, exec = _ref2.exec;
  EventEmitter = require('events').EventEmitter;
  Stream = require('net').Stream;
  packageBin = fs.realpathSync("" + __dirname + "/../../bin");
  packageLib = fs.realpathSync("" + __dirname + "/..");
  exports.Process = Process = (function() {
    __extends(Process, EventEmitter);
    function Process(config, options) {
      var raiseConfigError, self, _ref;
      this.config = config;
      self = this;
      this.id = Math.floor(Math.random() * 1000);
      options != null ? options : options = {};
      this.idle = options.idle;
      this.cwd = options.cwd;
      this.env = (_ref = options.env) != null ? _ref : {};
      this.state = null;
      this._connectionQueue = [];
      this._activeConnection = null;
      raiseConfigError = function() {
        return self.emit('error', new Error("configuration \"" + this.config + "\" doesn't exist"));
      };
      if (this.config != null) {
        exists(this.config, function(ok) {
          if (!ok) {
            return raiseConfigError();
          }
        });
      } else {
        raiseConfigError();
      }
      this.on('ready', function() {
        return self._processConnections();
      });
      this.on('error', function(error) {
        var callback;
        callback = self._activeConnection;
        self._activeConnection = null;
        if (callback) {
          return callback(error);
        } else if (self.listeners('error').length <= 1) {
          throw error;
        }
      });
      this.on('busy', function() {
        return self.deferTimeout();
      });
    }
    Process.prototype.spawn = function() {
      var env, key, tmp, value, _ref, _ref2;
      if (this.state) {
        return;
      }
      this.changeState('spawning');
      tmp = tmpFile();
      this.sockPath = "" + tmp + ".sock";
      env = {};
      _ref = process.env;
      for (key in _ref) {
        value = _ref[key];
        env[key] = value;
      }
      _ref2 = this.env;
      for (key in _ref2) {
        value = _ref2[key];
        env[key] = value;
      }
      env['PATH'] = "" + packageBin + ":" + env['PATH'];
      env['RUBYLIB'] = "" + packageLib + ":" + env['RUBYLIB'];
      this.heartbeat = new Stream;
      this.heartbeat.on('connect', __bind(function() {
        return this.emit('spawn');
      }, this));
      this.heartbeat.on('data', __bind(function(data) {
        var error, exception;
        if (("" + this.child.pid + "\n") === data.toString()) {
          return this.changeState('ready');
        } else {
          try {
            exception = JSON.parse(data);
            error = new Error(exception.message);
            error.name = exception.name;
            error.stack = exception.stack;
            return this.emit('error', error);
          } catch (e) {
            return this.emit('error', new Error("unknown process error"));
          }
        }
      }, this));
      tryConnect(this.heartbeat, this.sockPath, __bind(function(err) {
        if (err) {
          return this.emit('error', err);
        }
      }, this));
      this.child = spawn("nack_worker", [this.config, this.sockPath], {
        cwd: this.cwd,
        env: env
      });
      this.stdout = this.child.stdout;
      this.stderr = this.child.stderr;
      this.child.on('exit', __bind(function(code, signal) {
        this.clearTimeout();
        if (this.heartbeat) {
          this.heartbeat.destroy();
        }
        this.state = this.sockPath = null;
        this.child = this.heartbeat = null;
        this.stdout = this.stderr = null;
        this._connectionQueue = [];
        this._activeConnection = null;
        return this.emit('exit');
      }, this));
      return this;
    };
    if (!EventEmitter.prototype.once) {
      Process.prototype.once = function(event, listener) {
        var callback, self;
        self = this;
        callback = function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          self.removeListener(event, callback);
          return listener.apply(null, args);
        };
        return this.on(event, callback);
      };
    }
    Process.prototype.changeState = function(state) {
      var self;
      self = this;
      if (this.state !== state) {
        this.state = state;
        return process.nextTick(function() {
          return self.emit(state);
        });
      }
    };
    Process.prototype.clearTimeout = function() {
      if (this._timeoutId) {
        return clearTimeout(this._timeoutId);
      }
    };
    Process.prototype.deferTimeout = function() {
      var callback, self;
      self = this;
      if (this.idle) {
        this.clearTimeout();
        callback = function() {
          self.emit('idle');
          return self.quit();
        };
        return this._timeoutId = setTimeout(callback, this.idle);
      }
    };
    Process.prototype._processConnections = function() {
      var connection, self;
      self = this;
      if (!this._activeConnection) {
        this._activeConnection = this._connectionQueue.shift();
      }
      if (this._activeConnection && this.state === 'ready') {
        this.changeState('busy');
        connection = client.createConnection(this.sockPath);
        connection.on('close', function() {
          self._activeConnection = null;
          return self.changeState('ready');
        });
        return this._activeConnection(null, connection);
      } else {
        return this.spawn();
      }
    };
    Process.prototype.createConnection = function(callback) {
      this._connectionQueue.push(callback);
      this._processConnections();
      return this;
    };
    Process.prototype.proxyRequest = function() {
      var args, callback, metaVariables, req, res, resume, self;
      req = arguments[0], res = arguments[1], args = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
      self = this;
      if (isFunction(args[0])) {
        callback = args[0];
      } else {
        metaVariables = args[0];
        callback = args[1];
      }
      resume = pause(req);
      return this.createConnection(function(err, connection) {
        if (err) {
          if (callback) {
            callback(err);
          } else {
            self.emit('error', err);
          }
        } else {
          if (callback) {
            connection.on('close', callback);
            connection.on('error', function(error) {
              connection.removeListener('close', callback);
              return callback(error);
            });
          }
          connection.proxyRequest(req, res, metaVariables);
        }
        return resume();
      });
    };
    Process.prototype.kill = function() {
      if (this.child) {
        this.changeState('quitting');
        return this.child.kill('SIGKILL');
      }
    };
    Process.prototype.terminate = function() {
      var timeout;
      if (this.child) {
        this.changeState('quitting');
        this.child.kill('SIGTERM');
        timeout = setTimeout(__bind(function() {
          if (this.state === 'quitting') {
            return this.kill();
          }
        }, this), 10000);
        return this.once('exit', function() {
          return clearTimeout(timeout);
        });
      }
    };
    Process.prototype.quit = function() {
      var timeout;
      if (this.child) {
        this.changeState('quitting');
        this.child.kill('SIGQUIT');
        timeout = setTimeout(__bind(function() {
          if (this.state === 'quitting') {
            return this.terminate();
          }
        }, this), 3000);
        return this.once('exit', function() {
          return clearTimeout(timeout);
        });
      }
    };
    Process.prototype.restart = function() {
      this.once('exit', __bind(function() {
        return this.spawn();
      }, this));
      return this.quit();
    };
    return Process;
  })();
  exports.createProcess = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return typeof result === "object" ? result : child;
    })(Process, args, function() {});
  };
  tmpFile = function() {
    var pid, rand;
    pid = process.pid;
    rand = Math.floor(Math.random() * 10000000000);
    return "/tmp/nack." + pid + "." + rand;
  };
  onceFileExists = function(path, callback, count) {
    if (count == null) {
      count = 0;
    }
    if (count > 1000) {
      return callback(new Error("timeout"));
    }
    return fs.stat(path, function(err, stats) {
      if (!err) {
        return callback(err, path);
      } else {
        return process.nextTick(function() {
          return onceFileExists(path, callback, count + 1);
        });
      }
    });
  };
  tryConnect = function(connection, path, callback) {
    var errors, onError;
    errors = 0;
    onError = function(err) {
      if (++errors > 3) {
        connection.removeListener('error', onError);
        return callback(err);
      } else {
        return connection.connect(path);
      }
    };
    connection.on('error', onError);
    connection.on('connect', function() {
      connection.removeListener('error', onError);
      return callback(null, connection);
    });
    return onceFileExists(path, function(err) {
      if (err) {
        return callback(err);
      }
      return connection.connect(path);
    });
  };
}).call(this);
