(function() {
  var BufferedRequest, EventEmitter, LineBuffer, Process, Stream, client, debug, dirname, exec, exists, fs, isFunction, onceFileExists, packageBin, packageLib, spawn, tmpFile, tryConnect, _ref, _ref2, _ref3;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice;
  client = require('./client');
  fs = require('fs');
  _ref = require('path'), exists = _ref.exists, dirname = _ref.dirname;
  _ref2 = require('./util'), debug = _ref2.debug, isFunction = _ref2.isFunction;
  BufferedRequest = require('./util').BufferedRequest;
  LineBuffer = require('./util').LineBuffer;
  _ref3 = require('child_process'), spawn = _ref3.spawn, exec = _ref3.exec;
  EventEmitter = require('events').EventEmitter;
  Stream = require('net').Stream;
  packageLib = fs.realpathSync(__dirname);
  packageBin = fs.realpathSync("" + __dirname + "/../bin");
  exports.Process = Process = (function() {
    __extends(Process, EventEmitter);
    function Process(config, options) {
      var raiseConfigError, _ref4, _ref5, _ref6;
      this.config = config;
      this.proxy = __bind(this.proxy, this);
      this.id = Math.floor(Math.random() * 1000);
      if (options == null) {
        options = {};
      }
      this.runOnce = (_ref4 = options.runOnce) != null ? _ref4 : false;
      this.idle = options.idle;
      this.cwd = (_ref5 = options.cwd) != null ? _ref5 : dirname(this.config);
      this.env = (_ref6 = options.env) != null ? _ref6 : {};
      this.state = null;
      this._connectionQueue = [];
      this._activeConnection = null;
      raiseConfigError = __bind(function() {
        return this._handleError(new Error("configuration \"" + this.config + "\" doesn't exist"));
      }, this);
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
      var env, key, logData, onSpawn, out, value, _ref4, _ref5;
      if (this.state) {
        return;
      }
      debug("spawning process #" + this.id);
      if (callback != null) {
        onSpawn = __bind(function(err) {
          this.removeListener('ready', onSpawn);
          this.removeListener('error', onSpawn);
          return callback(err);
        }, this);
        this.on('ready', onSpawn);
        this.on('error', onSpawn);
      }
      this.changeState('spawning');
      this.sockPath = "" + (tmpFile()) + ".sock";
      env = {};
      _ref4 = process.env;
      for (key in _ref4) {
        value = _ref4[key];
        env[key] = value;
      }
      _ref5 = this.env;
      for (key in _ref5) {
        value = _ref5[key];
        env[key] = value;
      }
      env['PATH'] = "" + packageBin + ":" + env['PATH'];
      env['RUBYLIB'] = "" + packageLib + ":" + env['RUBYLIB'];
      this.heartbeat = new Stream;
      this.heartbeat.on('connect', __bind(function() {
        if (this.child.pid) {
          debug("process spawned #" + this.id);
          return this.emit('spawn');
        } else {
          return this._handleError(new Error("unknown process error"));
        }
      }, this));
      this.heartbeat.on('data', __bind(function(data) {
        var error, exception;
        if (this.child.pid && ("" + this.child.pid + "\n") === data.toString()) {
          this.changeState('ready');
          return this._processConnections();
        } else {
          try {
            exception = JSON.parse(data);
            error = new Error(exception.message);
            error.name = exception.name;
            error.stack = exception.stack;
            debug("heartbeat error", error);
            return this._handleError(error);
          } catch (e) {
            debug("heartbeat error", e);
            return this._handleError(new Error("unknown process error"));
          }
        }
      }, this));
      tryConnect(this.heartbeat, this.sockPath, __bind(function(err) {
        if (err && out) {
          return this._handleError(new Error(out));
        } else if (err) {
          return this._handleError(err);
        }
      }, this));
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
      this.on('spawn', __bind(function() {
        out = null;
        this.stdout.removeListener('data', logData);
        return this.stderr.removeListener('data', logData);
      }, this));
      this.child.on('exit', __bind(function(code, signal) {
        debug("process exited #" + this.id);
        this.clearTimeout();
        if (this.heartbeat) {
          this.heartbeat.destroy();
        }
        this.state = this.sockPath = null;
        this.child = this.heartbeat = null;
        this.stdout = this.stderr = null;
        return this.emit('exit');
      }, this));
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
      var connection;
      if (!this._activeConnection && this._connectionQueue.length) {
        debug("accepted connection 1/" + this._connectionQueue.length + " #" + this.id);
        this._activeConnection = this._connectionQueue.shift();
      }
      if (this._activeConnection && this.state === 'ready') {
        this.deferTimeout();
        this.changeState('busy');
        connection = client.createConnection(this.sockPath);
        connection.on('close', __bind(function() {
          delete this._activeConnection;
          if (this.runOnce) {
            return this.quit(__bind(function() {
              return this._processConnections();
            }, this));
          } else {
            this.changeState('ready');
            return this._processConnections();
          }
        }, this));
        return setTimeout(__bind(function() {
          return this._activeConnection(null, connection);
        }, this), 0);
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
      var args, req;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      req = (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return typeof result === "object" ? result : child;
      })(BufferedRequest, args, function() {});
      req.proxyMetaVariables['rack.run_once'] = this.runOnce;
      this.createConnection(__bind(function(err, connection) {
        var clientRequest;
        if (err) {
          return req.emit('error', err);
        } else {
          debug("proxy " + req.method + " " + req.url + " to #" + this.id);
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
      }, this));
      return req;
    };
    Process.prototype.proxy = function(req, res, next) {
      var clientRequest;
      clientRequest = this.request();
      clientRequest.on('error', next);
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
      var timeout;
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
        timeout = setTimeout(__bind(function() {
          if (this.state === 'quitting') {
            debug("process is hung, sending kill to #" + this.id);
            return this.kill();
          }
        }, this), 10000);
        return this.once('exit', function() {
          return clearTimeout(timeout);
        });
      } else {
        return typeof callback === "function" ? callback() : void 0;
      }
    };
    Process.prototype.quit = function(callback) {
      var timeout;
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
        timeout = setTimeout(__bind(function() {
          if (this.state === 'quitting') {
            return this.terminate();
          }
        }, this), 3000);
        return this.once('exit', function() {
          return clearTimeout(timeout);
        });
      } else {
        return typeof callback === "function" ? callback() : void 0;
      }
    };
    Process.prototype.restart = function(callback) {
      debug("process restart #" + this.id);
      return this.quit(__bind(function() {
        return this.spawn(callback);
      }, this));
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
}).call(this);
