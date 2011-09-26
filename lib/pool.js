(function() {
  var AggregateStream, EventEmitter, Pool, Stream, async, createProcess, isFunction;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice;
  async = require('async');
  EventEmitter = require('events').EventEmitter;
  Stream = require('stream').Stream;
  createProcess = require('./process').createProcess;
  isFunction = require('./util').isFunction;
  exports.Pool = Pool = (function() {
    __extends(Pool, EventEmitter);
    function Pool(config, options) {
      var n, previousReadyWorkerCount, self, _ref, _ref2;
      this.config = config;
      this.proxy = __bind(this.proxy, this);
      if (options == null) {
        options = {};
      }
      if ((_ref = options.size) == null) {
        options.size = 1;
      }
      this.workers = [];
      this.round = 0;
      this.processOptions = {
        runOnce: options.runOnce,
        idle: options.idle,
        cwd: options.cwd,
        env: options.env
      };
      this.stdout = new AggregateStream;
      this.stderr = new AggregateStream;
      self = this;
      previousReadyWorkerCount = 0;
      this.on('worker:ready', function() {
        var newReadyWorkerCount;
        newReadyWorkerCount = self.getReadyWorkerCount();
        if (previousReadyWorkerCount === 0 && newReadyWorkerCount > 0) {
          self.emit('ready');
        }
        return previousReadyWorkerCount = newReadyWorkerCount;
      });
      this.on('worker:exit', function() {
        if (self.getAliveWorkerCount() === 0) {
          return self.emit('exit');
        }
      });
      for (n = 1, _ref2 = options.size; 1 <= _ref2 ? n <= _ref2 : n >= _ref2; 1 <= _ref2 ? n++ : n--) {
        this.increment();
      }
    }
    Pool.prototype.__defineGetter__('runOnce', function() {
      return this.processOptions.runOnce;
    });
    Pool.prototype.__defineSetter__('runOnce', function(value) {
      var worker, _i, _len, _ref;
      _ref = this.workers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        worker.runOnce = value;
      }
      return this.processOptions.runOnce = value;
    });
    Pool.prototype.getAliveWorkerCount = function() {
      var count, worker, _i, _len, _ref;
      count = 0;
      _ref = this.workers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        if (worker.state) {
          count++;
        }
      }
      return count;
    };
    Pool.prototype.getReadyWorkerCount = function() {
      var count, worker, _i, _len, _ref;
      count = 0;
      _ref = this.workers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        if (worker.state === 'ready') {
          count++;
        }
      }
      return count;
    };
    Pool.prototype.nextWorker = function() {
      var worker, _i, _len, _ref;
      _ref = this.workers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        if (worker.state === 'ready') {
          return worker;
        }
      }
      worker = this.workers[this.round];
      this.round += 1;
      this.round %= this.workers.length;
      return worker;
    };
    Pool.prototype.increment = function() {
      var process, self;
      process = createProcess(this.config, this.processOptions);
      this.workers.push(process);
      self = this;
      process.on('spawn', function() {
        self.stdout.add(process.stdout, process);
        self.stderr.add(process.stderr, process);
        return self.emit('worker:spawn', process);
      });
      process.on('ready', function() {
        return self.emit('worker:ready', process);
      });
      process.on('busy', function() {
        return self.emit('worker:busy', process);
      });
      process.on('error', function(error) {
        return self.emit('worker:error', process, error);
      });
      process.on('exit', function() {
        return self.emit('worker:exit', process);
      });
      return process;
    };
    Pool.prototype.decrement = function() {
      var worker;
      if (worker = this.workers.shift()) {
        return worker.quit();
      }
    };
    Pool.prototype.spawn = function() {
      var spawn;
      spawn = function(worker, callback) {
        return worker.spawn(callback);
      };
      return async.forEach(this.workers, spawn, typeof callback !== "undefined" && callback !== null ? callback : function() {});
    };
    Pool.prototype.terminate = function(callback) {
      var terminate;
      terminate = function(worker, callback) {
        return worker.terminate(callback);
      };
      return async.forEach(this.workers, terminate, callback != null ? callback : function() {});
    };
    Pool.prototype.quit = function(callback) {
      var quit;
      quit = function(worker, callback) {
        return worker.quit(callback);
      };
      return async.forEach(this.workers, quit, callback != null ? callback : function() {});
    };
    Pool.prototype.restart = function(callback) {
      var restart;
      restart = function(worker, callback) {
        return worker.restart(callback);
      };
      return async.forEach(this.workers, restart, callback != null ? callback : function() {});
    };
    Pool.prototype.request = function() {
      var args, worker;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      worker = this.nextWorker();
      return worker.request.apply(worker, args);
    };
    Pool.prototype.proxy = function(req, res, next) {
      var worker;
      worker = this.nextWorker();
      return worker.proxy(req, res, next);
    };
    return Pool;
  })();
  exports.createPool = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return typeof result === "object" ? result : child;
    })(Pool, args, function() {});
  };
  AggregateStream = (function() {
    __extends(AggregateStream, Stream);
    function AggregateStream() {
      AggregateStream.__super__.constructor.apply(this, arguments);
    }
    AggregateStream.prototype.add = function(stream, process) {
      var self;
      self = this;
      stream.on('data', function(data) {
        return self.emit('data', data, process);
      });
      return stream.on('error', function(exception) {
        return self.emit('error', exception, process);
      });
    };
    return AggregateStream;
  })();
}).call(this);
