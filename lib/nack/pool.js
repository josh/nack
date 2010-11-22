(function() {
  var AggregateStream, EventEmitter, Pool, createProcess, pause;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice;
  EventEmitter = require('events').EventEmitter;
  createProcess = require('./process').createProcess;
  pause = require('./util').pause;
  exports.Pool = Pool = function() {
    function Pool(config, options) {
      var n, previousReadyWorkerCount, _ref, _ref2;
      this.config = config;
      options != null ? options : options = {};
      (_ref = options.size) != null ? _ref : options.size = 1;
      this.workers = [];
      this.processOptions = {
        idle: options.idle,
        debug: options.debug,
        cwd: options.cwd
      };
      this.stdout = new AggregateStream;
      this.stderr = new AggregateStream;
      previousReadyWorkerCount = 0;
      this.on('worker:ready', __bind(function() {
        var newReadyWorkerCount;
        newReadyWorkerCount = this.getReadyWorkerCount();
        if (previousReadyWorkerCount === 0 && newReadyWorkerCount > 0) {
          this.emit('ready');
        }
        return previousReadyWorkerCount = newReadyWorkerCount;
      }, this));
      this.on('worker:exit', __bind(function() {
        if (this.getAliveWorkerCount() === 0) {
          return this.emit('exit');
        }
      }, this));
      for (n = 1, _ref2 = options.size; (1 <= _ref2 ? n <= _ref2 : n >= _ref2); (1 <= _ref2 ? n += 1 : n -= 1)) {
        this.increment();
      }
    }
    __extends(Pool, EventEmitter);
    Pool.prototype.onNext = function(event, listener) {
      var callback;
      callback = __bind(function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        this.removeListener(event, callback);
        return listener.apply(listener, args);
      }, this);
      return this.on(event, callback);
    };
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
    Pool.prototype.increment = function() {
      var process;
      process = createProcess(this.config, this.processOptions);
      this.workers.push(process);
      process.on('spawn', __bind(function() {
        this.stdout.add(process.stdout, process);
        this.stderr.add(process.stderr, process);
        return this.emit('worker:spawn', process);
      }, this));
      process.on('ready', __bind(function() {
        return this.emit('worker:ready', process);
      }, this));
      process.on('busy', __bind(function() {
        return this.emit('worker:busy', process);
      }, this));
      process.on('exit', __bind(function() {
        return this.emit('worker:exit', process);
      }, this));
      return process;
    };
    Pool.prototype.decrement = function() {
      var worker;
      if (worker = this.workers.shift()) {
        return worker.quit();
      }
    };
    Pool.prototype.announceReadyWorkers = function() {
      var oneReady, _fn, _i, _len, _ref, _results;
      oneReady = false;
      _ref = this.workers;
      _fn = function(worker) {
        return _results.push(worker.state === 'ready' ? (oneReady = true, process.nextTick(__bind(function() {
          return this.emit('worker:ready', worker);
        }, this))) : oneReady === false && !worker.state ? (oneReady = true, process.nextTick(function() {
          return worker.spawn();
        })) : void 0);
      };
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        _fn.call(this, worker);
      }
      return _results;
    };
    Pool.prototype.spawn = function() {
      var worker, _i, _len, _ref, _results;
      _ref = this.workers;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        _results.push(worker.spawn());
      }
      return _results;
    };
    Pool.prototype.terminate = function() {
      var worker, _i, _len, _ref, _results;
      _ref = this.workers;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        _results.push(worker.terminate());
      }
      return _results;
    };
    Pool.prototype.quit = function() {
      var worker, _i, _len, _ref, _results;
      _ref = this.workers;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        _results.push(worker.quit());
      }
      return _results;
    };
    Pool.prototype.proxyRequest = function(req, res, callback) {
      var resume;
      resume = pause(req);
      this.onNext('worker:ready', function(worker) {
        return worker.createConnection(function(connection) {
          connection.proxyRequest(req, res);
          if (callback) {
            connection.on('error', callback);
            connection.on('close', callback);
          }
          return resume();
        });
      });
      return this.announceReadyWorkers();
    };
    return Pool;
  }();
  exports.createPool = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return typeof result === "object" ? result : child;
    })(Pool, args, function() {});
  };
  AggregateStream = function() {
    function AggregateStream() {
      AggregateStream.__super__.constructor.apply(this, arguments);
    }
    __extends(AggregateStream, EventEmitter);
    AggregateStream.prototype.add = function(stream, process) {
      stream.on('data', __bind(function(data) {
        return this.emit('data', data, process);
      }, this));
      return stream.on('error', __bind(function(exception) {
        return this.emit('error', exception, process);
      }, this));
    };
    return AggregateStream;
  }();
}).call(this);
