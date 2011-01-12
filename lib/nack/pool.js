(function() {
  var AggregateStream, EventEmitter, Pool, createProcess, isFunction, pause, _ref;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice;
  EventEmitter = require('events').EventEmitter;
  createProcess = require('./process').createProcess;
  _ref = require('./util'), pause = _ref.pause, isFunction = _ref.isFunction;
  exports.Pool = Pool = (function() {
    __extends(Pool, EventEmitter);
    function Pool(config, options) {
      var n, previousReadyWorkerCount, self, _ref, _ref2;
      this.config = config;
      options != null ? options : options = {};
      (_ref = options.size) != null ? _ref : options.size = 1;
      this.workers = [];
      this.processOptions = {
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
      for (n = 1, _ref2 = options.size; (1 <= _ref2 ? n <= _ref2 : n >= _ref2); (1 <= _ref2 ? n += 1 : n -= 1)) {
        this.increment();
      }
    }
    if (!EventEmitter.prototype.once) {
      Pool.prototype.once = function(event, listener) {
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
    Pool.prototype.announceReadyWorkers = function() {
      var oneReady, self, worker, _i, _len, _ref, _results;
      self = this;
      oneReady = false;
      _ref = this.workers;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        worker = _ref[_i];
        _results.push(worker.state === 'ready' ? (oneReady = true, process.nextTick(function() {
          return self.emit('worker:ready', worker);
        })) : oneReady === false && !worker.state ? (oneReady = true, process.nextTick(function() {
          return worker.spawn();
        })) : void 0);
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
    Pool.prototype.proxyRequest = function() {
      var args, callback, errorListener, metaVariables, req, res, resume, self;
      req = arguments[0], res = arguments[1], args = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
      self = this;
      if (isFunction(args[0])) {
        callback = args[0];
      } else {
        metaVariables = args[0];
        callback = args[1];
      }
      if (callback) {
        errorListener = function(process, error) {
          self.removeListener('worker:error', errorListener);
          return callback(error);
        };
        this.on('worker:error', errorListener);
      }
      resume = pause(req);
      this.once('worker:ready', function(worker) {
        self.removeListener('worker:error', errorListener);
        worker.proxyRequest.apply(worker, [req, res].concat(__slice.call(args)));
        return resume();
      });
      return this.announceReadyWorkers();
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
    function AggregateStream() {
      AggregateStream.__super__.constructor.apply(this, arguments);
    }
    __extends(AggregateStream, EventEmitter);
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
