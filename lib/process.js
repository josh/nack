// Generated by CoffeeScript 1.6.2
(function() {
  var BufferedRequest, EventEmitter, LineBuffer, Process, Stream, client, debug, dirname, exec, exists, fs, installOnce, isFunction, onceFileExists, packageBin, packageLib, spawn, tmpFile, tryConnect, _ref, _ref1, _ref2,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  client = require('./client');

  fs = require('fs');

  dirname = require('path').dirname;

  _ref = require('./util'), debug = _ref.debug, isFunction = _ref.isFunction;

  BufferedRequest = require('./util').BufferedRequest;

  LineBuffer = require('./util').LineBuffer;

  _ref1 = require('child_process'), spawn = _ref1.spawn, exec = _ref1.exec;

  EventEmitter = require('events').EventEmitter;

  Stream = require('net').Stream;

  exists = (_ref2 = fs.exists) != null ? _ref2 : require('path').exists;

  packageLib = fs.realpathSync(__dirname);

  packageBin = fs.realpathSync("" + __dirname + "/../bin");

  exports.Process = Process = (function(_super) {
    __extends(Process, _super);

    function Process(config, options) {
      var raiseConfigError, _ref3, _ref4, _ref5,
        _this = this;

      this.config = config;
      this.quit = __bind(this.quit, this);
      this.proxy = __bind(this.proxy, this);
      this.id = Math.floor(Math.random() * 1000);
      if (options == null) {
        options = {};
      }
      this.runOnce = (_ref3 = options.runOnce) != null ? _ref3 : false;
      this.idle = options.idle;
      this.cwd = (_ref4 = options.cwd) != null ? _ref4 : dirname(this.config);
      this.env = (_ref5 = options.env) != null ? _ref5 : {};
      this.state = null;
      this._connectionQueue = [];
      this._activeConnection = null;
      raiseConfigError = function() {
        return _this._handleError(new Error("configuration \"" + _this.config + "\" doesn't exist"));
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
    }

    Process.prototype.__defineGetter__('runOnce', function() {
      return this._runOnce;
    });

    Process.prototype.__defineSetter__('runOnce', function(value) {
      if (this._runOnce === false && value === true && this.child) {
        debug("enabling runOnce on process #" + this.id);
        this.restart();
      }
      return this._runOnce = value;
    });

    Process.prototype.spawn = function(callback) {
      var env, key, logData, onSpawn, out, value, _ref3, _ref4,
        _this = this;

      if (this.state) {
        return;
      }
      debug("spawning process #" + this.id);
      if (callback != null) {
        onSpawn = function(err) {
          _this.removeListener('ready', onSpawn);
          _this.removeListener('error', onSpawn);
          return callback(err);
        };
        this.on('ready', onSpawn);
        this.on('error', onSpawn);
      }
      this.changeState('spawning');
      this.sockPath = "" + (tmpFile()) + ".sock";
      env = {};
      _ref3 = process.env;
      for (key in _ref3) {
        value = _ref3[key];
        env[key] = value;
      }
      _ref4 = this.env;
      for (key in _ref4) {
        value = _ref4[key];
        env[key] = value;
      }
      env['PATH'] = "" + packageBin + ":" + env['PATH'];
      env['RUBYLIB'] = "" + packageLib + ":" + env['RUBYLIB'];
      this.heartbeat = new Stream;
      this.heartbeat.on('connect', function() {
        if (_this.child.pid) {
          debug("process spawned #" + _this.id);
          return _this.emit('spawn');
        } else {
          return _this._handleError(new Error("unknown process error"));
        }
      });
      this.heartbeat.on('data', function(data) {
        var e, error, exception;

        if (_this.child.pid && ("" + _this.child.pid + "\n") === data.toString()) {
          _this.changeState('ready');
          return _this._processConnections();
        } else {
          try {
            exception = JSON.parse(data);
            error = new Error(exception.message);
            error.name = exception.name;
            error.stack = exception.stack;
            debug("heartbeat error", error);
            return _this._handleError(error);
          } catch (_error) {
            e = _error;
            debug("heartbeat error", e);
            return _this._handleError(new Error("unknown process error"));
          }
        }
      });
      tryConnect(this.heartbeat, this.sockPath, function(err) {
        if (err && out) {
          return _this._handleError(new Error(out));
        } else if (err) {
          return _this._handleError(err);
        }
      });
      this.child = spawn("nack_worker", [this.config, this.sockPath], {
        cwd: this.cwd,
        env: env
      });
      this.stdout = this.child.stdout;
      this.stderr = this.child.stderr;
      out = null;
      logData = function(data) {
        if (out == null) {
          out = "";
        }
        return out += data.toString();
      };
      this.stdout.on('data', logData);
      this.stderr.on('data', logData);
      this.on('spawn', function() {
        out = null;
        _this.stdout.removeListener('data', logData);
        return _this.stderr.removeListener('data', logData);
      });
      this.child.on('exit', function(code, signal) {
        debug("process exited #" + _this.id);
        _this.clearTimeout();
        if (_this.heartbeat) {
          _this.heartbeat.destroy();
        }
        _this.state = _this.sockPath = null;
        _this.child = _this.heartbeat = null;
        _this.stdout = _this.stderr = null;
        return _this.emit('exit');
      });
      return this;
    };

    Process.prototype.changeState = function(state) {
      if (this.state !== state) {
        this.state = state;
        return this.emit(state);
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
      var connection,
        _this = this;

      if (!this._activeConnection && this._connectionQueue.length) {
        debug("accepted connection 1/" + this._connectionQueue.length + " #" + this.id);
        this._activeConnection = this._connectionQueue.shift();
      }
      if (this._activeConnection && this.state === 'ready') {
        this.deferTimeout();
        this.changeState('busy');
        connection = client.createConnection(this.sockPath);
        connection.on('close', function() {
          delete _this._activeConnection;
          if (_this.runOnce) {
            return _this.quit(function() {
              return _this._processConnections();
            });
          } else {
            _this.changeState('ready');
            return _this._processConnections();
          }
        });
        return setTimeout(function() {
          return _this._activeConnection(null, connection);
        }, 0);
      } else if (this._activeConnection || this._connectionQueue.length) {
        return this.spawn();
      }
    };

    Process.prototype._handleError = function(error) {
      var callback;

      callback = this._activeConnection;
      delete this._activeConnection;
      if (callback) {
        return callback(error);
      } else {
        return this.emit('error', error);
      }
    };

    Process.prototype.createConnection = function(callback) {
      this._connectionQueue.push(callback);
      this._processConnections();
      return this;
    };

    Process.prototype.request = function() {
      var args, req,
        _this = this;

      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      req = (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(BufferedRequest, args, function(){});
      req.proxyMetaVariables['rack.run_once'] = this.runOnce;
      this.createConnection(function(err, connection) {
        var clientRequest;

        if (err) {
          return req.emit('error', err);
        } else {
          debug("proxy " + req.method + " " + req.url + " to #" + _this.id);
          clientRequest = connection.request();
          clientRequest.on('error', function(err) {
            return req.emit('error', err);
          });
          clientRequest.on('response', function(response) {
            return req.emit('response', response);
          });
          req.pipe(clientRequest);
          return req.flush();
        }
      });
      return req;
    };

    Process.prototype.proxy = function(req, res, next) {
      var clientRequest;

      installOnce(req.connection.server, 'close', this.quit);
      clientRequest = this.request();
      if (next != null) {
        clientRequest.on('error', next);
      }
      clientRequest.on('response', function(clientResponse) {
        return clientResponse.pipe(res);
      });
      return req.pipe(clientRequest);
    };

    Process.prototype.kill = function(callback) {
      debug("process kill #" + this.id);
      if (this.child) {
        this.changeState('quitting');
        if (callback) {
          this.once('exit', callback);
        }
        this.child.kill('SIGKILL');
        if (this.heartbeat) {
          return this.heartbeat.destroy();
        }
      } else {
        return typeof callback === "function" ? callback() : void 0;
      }
    };

    Process.prototype.terminate = function(callback) {
      var timeout,
        _this = this;

      debug("process terminate #" + this.id);
      if (this.child) {
        this.changeState('quitting');
        if (callback) {
          this.once('exit', callback);
        }
        this.child.kill('SIGTERM');
        if (this.heartbeat) {
          this.heartbeat.destroy();
        }
        timeout = setTimeout(function() {
          if (_this.state === 'quitting') {
            debug("process is hung, sending kill to #" + _this.id);
            return _this.kill();
          }
        }, 10000);
        return this.once('exit', function() {
          return clearTimeout(timeout);
        });
      } else {
        return typeof callback === "function" ? callback() : void 0;
      }
    };

    Process.prototype.quit = function(callback) {
      var timeout,
        _this = this;

      debug("process quit #" + this.id);
      if (this.child) {
        this.changeState('quitting');
        if (callback) {
          this.once('exit', callback);
        }
        this.child.kill('SIGQUIT');
        if (this.heartbeat) {
          this.heartbeat.destroy();
        }
        timeout = setTimeout(function() {
          if (_this.state === 'quitting') {
            return _this.terminate();
          }
        }, 3000);
        return this.once('exit', function() {
          return clearTimeout(timeout);
        });
      } else {
        return typeof callback === "function" ? callback() : void 0;
      }
    };

    Process.prototype.restart = function(callback) {
      var _this = this;

      debug("process restart #" + this.id);
      return this.quit(function() {
        return _this.spawn(callback);
      });
    };

    return Process;

  })(EventEmitter);

  exports.createProcess = function() {
    var args;

    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return Object(result) === result ? result : child;
    })(Process, args, function(){});
  };

  tmpFile = function() {
    var pid, rand;

    pid = process.pid;
    rand = Math.floor(Math.random() * 10000000000);
    return "/tmp/nack." + pid + "." + rand;
  };

  onceFileExists = function(path, callback, timeout) {
    var decay, statPath, timeoutError, timeoutId;

    if (timeout == null) {
      timeout = 3000;
    }
    timeoutError = null;
    timeoutId = setTimeout(function() {
      return timeoutError = new Error("timeout: waiting for " + path);
    }, timeout);
    decay = 1;
    statPath = function(err, stat) {
      if (!err && stat && stat.isSocket()) {
        clearTimeout(timeoutId);
        return callback(err, path);
      } else if (timeoutError) {
        return callback(timeoutError, path);
      } else {
        return setTimeout(function() {
          return fs.stat(path, statPath);
        }, decay *= 2);
      }
    };
    return statPath();
  };

  tryConnect = function(connection, path, callback) {
    var errors, onError, reconnect;

    errors = 0;
    reconnect = function() {
      return onceFileExists(path, function(err) {
        if (err) {
          return callback(err);
        }
        return connection.connect(path);
      });
    };
    onError = function(err) {
      if (err && ++errors > 3) {
        connection.removeListener('error', onError);
        return callback(new Error("timeout: couldn't connect to " + path));
      } else {
        return reconnect();
      }
    };
    connection.on('error', onError);
    connection.on('connect', function() {
      connection.removeListener('error', onError);
      return callback(null, connection);
    });
    return reconnect();
  };

  installOnce = function(emitter, type, listener) {
    var event, events, _i, _len;

    if (events = emitter._events[type]) {
      if (events === listener) {
        return;
      }
      for (_i = 0, _len = events.length; _i < _len; _i++) {
        event = events[_i];
        if (event === listener) {
          return;
        }
      }
    }
    return emitter.on(type, listener);
  };

}).call(this);
