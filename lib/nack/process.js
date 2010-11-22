(function() {
  var EventEmitter, Process, client, createPipeStream, exec, exists, fs, pause, spawn, tmpFile, _ref;
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
  exists = require('path').exists;
  pause = require('./util').pause;
  _ref = require('child_process'), spawn = _ref.spawn, exec = _ref.exec;
  EventEmitter = require('events').EventEmitter;
  exports.Process = Process = function() {
    function Process(config, options) {
      var raiseConfigError;
      this.config = config;
      options != null ? options : options = {};
      this.idle = options.idle;
      this.cwd = options.cwd;
      this.debug = options.debug;
      this.state = null;
      raiseConfigError = __bind(function() {
        return this.emit('error', new Error("configuration \"" + this.config + "\" doesn't exist"));
      }, this);
      if (this.config != null) {
        exists(this.config, __bind(function(ok) {
          if (!ok) {
            return raiseConfigError();
          }
        }, this));
      } else {
        raiseConfigError();
      }
      this.on('busy', __bind(function() {
        return this.deferTimeout();
      }, this));
    }
    __extends(Process, EventEmitter);
    Process.prototype.getNackWorkerPath = function(callback) {
      if (this.nackWorkerPath != null) {
        return callback(null, this.nackWorkerPath);
      } else {
        return exec('which nack_worker', __bind(function(error, stdout, stderr) {
          if (error) {
            return callback(new Error("Couldn't find `nack_worker` in PATH"));
          } else {
            this.nackWorkerPath = stdout.replace(/(\n|\r)+$/, '');
            return callback(error, this.nackWorkerPath);
          }
        }, this));
      }
    };
    Process.prototype.spawn = function() {
      if (this.state) {
        return;
      }
      this.changeState('spawning');
      this.getNackWorkerPath(__bind(function(err, nackWorker) {
        var tmp;
        if (err) {
          return this.emit('error', err);
        }
        tmp = tmpFile();
        this.sockPath = "" + tmp + ".sock";
        this.pipePath = "" + tmp + ".pipe";
        return createPipeStream(this.pipePath, __bind(function(err, pipe) {
          var args;
          if (err) {
            return this.emit('error', err);
          }
          args = ['--file', this.sockPath, '--pipe', this.pipePath];
          if (this.debug) {
            args.push('--debug');
          }
          args.push(this.config);
          this.child = spawn(nackWorker, args, {
            cwd: this.cwd,
            env: process.env
          });
          this.stdout = this.child.stdout;
          this.stderr = this.child.stderr;
          pipe.on('end', __bind(function() {
            pipe = null;
            this.pipe = fs.createWriteStream(this.pipePath);
            return this.pipe.on('open', __bind(function() {
              return this.changeState('ready');
            }, this));
          }, this));
          this.child.on('exit', __bind(function(code, signal) {
            this.clearTimeout();
            if (this.pipe) {
              this.pipe.end();
            }
            this.state = this.sockPath = this.pipePath = null;
            this.child = this.pipe = null;
            this.stdout = this.stderr = null;
            return this.emit('exit');
          }, this));
          return this.emit('spawn');
        }, this));
      }, this));
      return this;
    };
    Process.prototype.onNext = function(event, listener) {
      var callback;
      callback = __bind(function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        this.removeListener(event, callback);
        return listener.apply(listener, args);
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
      if (this.state === state) {
        return callback();
      } else {
        return this.onNext(state, __bind(function() {
          return this.onState(state, callback);
        }, this));
      }
    };
    Process.prototype.clearTimeout = function() {
      if (this._timeoutId) {
        return clearTimeout(this._timeoutId);
      }
    };
    Process.prototype.deferTimeout = function() {
      var callback;
      if (this.idle) {
        this.clearTimeout();
        callback = __bind(function() {
          this.emit('idle');
          return this.quit();
        }, this);
        return this._timeoutId = setTimeout(callback, this.idle);
      }
    };
    Process.prototype.createConnection = function(callback) {
      this.spawn();
      return this.onState('ready', __bind(function() {
        var connection;
        this.changeState('busy');
        connection = client.createConnection(this.sockPath);
        connection.on('close', __bind(function() {
          return this.changeState('ready');
        }, this));
        return callback(connection);
      }, this));
    };
    Process.prototype.proxyRequest = function(req, res, callback) {
      var resume;
      resume = pause(req);
      return this.createConnection(function(connection) {
        connection.proxyRequest(req, res);
        if (callback) {
          connection.on('error', callback);
          connection.on('close', callback);
        }
        return resume();
      });
    };
    Process.prototype.terminate = function() {
      if (this.child) {
        this.changeState('quitting');
        return this.child.kill('SIGTERM');
      }
    };
    Process.prototype.quit = function() {
      if (this.child) {
        this.changeState('quitting');
        return this.child.kill('SIGQUIT');
      }
    };
    return Process;
  }();
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
  createPipeStream = function(path, callback) {
    return exec("mkfifo " + path, __bind(function(error, stdout, stderr) {
      var stream;
      if (error != null) {
        return callback(error);
      } else {
        stream = fs.createReadStream(path);
        return callback(null, stream);
      }
    }, this));
  };
}).call(this);
