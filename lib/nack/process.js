(function() {
  var EventEmitter, LineBuffer, Process, client, createPipeStream, exec, exists, fs, isFunction, packageBin, packageLib, pause, spawn, tmpFile, _ref, _ref2;
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
  packageBin = fs.realpathSync("" + __dirname + "/../../bin");
  packageLib = fs.realpathSync("" + __dirname + "/..");
  exports.Process = Process = (function() {
    __extends(Process, EventEmitter);
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
        exists(this.config, function(ok) {
          if (!ok) {
            return raiseConfigError();
          }
        });
      } else {
        raiseConfigError();
      }
      this.on('busy', __bind(function() {
        return this.deferTimeout();
      }, this));
    }
    Process.prototype.spawn = function() {
      var env, key, tmp, value, _ref;
      if (this.state) {
        return;
      }
      this.changeState('spawning');
      tmp = tmpFile();
      this.sockPath = "" + tmp + ".sock";
      this.pipePath = "" + tmp + ".pipe";
      env = {};
      _ref = process.env;
      for (key in _ref) {
        value = _ref[key];
        env[key] = value;
      }
      env['PATH'] = "" + packageBin + ":" + env['PATH'];
      env['RUBYLIB'] = "" + packageLib + ":" + env['RUBYLIB'];
      createPipeStream(this.pipePath, __bind(function(err, pipe) {
        var args, pipeError;
        if (err) {
          return this.emit('error', err);
        }
        args = ['--file', this.sockPath, '--pipe', this.pipePath];
        if (this.debug) {
          args.push('--debug');
        }
        args.push(this.config);
        this.child = spawn("nack_worker", args, {
          cwd: this.cwd,
          env: env
        });
        this.stdout = this.child.stdout;
        this.stderr = this.child.stderr;
        pipeError = null;
        pipe.on('data', __bind(function(data) {
          var exception;
          if (!this.child || data.toString() !== this.child.pid.toString()) {
            try {
              exception = JSON.parse(data);
              pipeError = new Error(exception.message);
              pipeError.name = exception.name;
              return pipeError.stack = exception.stack;
            } catch (e) {
              return pipeError = new Error("unknown spawn error");
            }
          }
        }, this));
        pipe.on('end', __bind(function() {
          pipe = null;
          if (!pipeError) {
            this.pipe = fs.createWriteStream(this.pipePath);
            return this.pipe.on('open', __bind(function() {
              return this.changeState('ready');
            }, this));
          }
        }, this));
        this.child.on('exit', __bind(function(code, signal) {
          this.clearTimeout();
          if (this.pipe) {
            this.pipe.end();
          }
          this.state = this.sockPath = this.pipePath = null;
          this.child = this.pipe = null;
          this.stdout = this.stderr = null;
          if (code !== 0 && pipeError) {
            this.emit('error', pipeError);
          }
          return this.emit('exit');
        }, this));
        return this.emit('spawn');
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
    Process.prototype.onState = function(state, callback) {
      var self;
      self = this;
      if (this.state === state) {
        return callback();
      } else {
        return this.once(state, function() {
          return self.onState(state, callback);
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
    Process.prototype.createConnection = function(callback) {
      var self;
      self = this;
      this.spawn();
      return this.onState('ready', function() {
        var connection;
        self.changeState('busy');
        connection = client.createConnection(self.sockPath);
        connection.on('close', function() {
          return self.changeState('ready');
        });
        return callback(connection);
      });
    };
    Process.prototype.proxyRequest = function() {
      var args, callback, errorListener, metaVariables, req, res, resume, self;
      req = arguments[0], res = arguments[1], args = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
      self = this;
      if (isFunction(args[0])) {
        callback = args[0];
      } else {
        metaVariables = args[0];
        callback = args[1];
      }
      resume = pause(req);
      if (callback) {
        errorListener = function(error) {
          self.removeListener('error', errorListener);
          return callback(error);
        };
        this.on('error', errorListener);
      }
      return this.createConnection(function(connection) {
        connection.proxyRequest(req, res, metaVariables);
        if (callback) {
          connection.on('close', callback);
          connection.on('error', function(error) {
            connection.removeListener('close', callback);
            return callback(error);
          });
          self.removeListener('error', errorListener);
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
  createPipeStream = function(path, callback) {
    return exec("mkfifo " + path, function(error, stdout, stderr) {
      var stream;
      if (error != null) {
        return callback(error);
      } else {
        stream = fs.createReadStream(path);
        return callback(null, stream);
      }
    });
  };
}).call(this);
