(function() {
  var AggregateStream, EventEmitter, Pool, _ref, createProcess;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  }, __slice = Array.prototype.slice;
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  _ref = require('nack/process');
  createProcess = _ref.createProcess;
  AggregateStream = function() {
    return EventEmitter.apply(this, arguments);
  };
  __extends(AggregateStream, EventEmitter);
  AggregateStream.prototype.add = function(stream, process) {
    stream.on('data', __bind(function(data) {
      return this.emit('data', data, process);
    }, this));
    stream.on('error', __bind(function(exception) {
      return this.emit('error', exception, process);
    }, this));
    stream.on('end', __bind(function() {
      return this.emit('end', process);
    }, this));
    return stream.on('close', __bind(function() {
      return this.emit('close', process);
    }, this));
  };
  exports.Pool = (function() {
    Pool = function(_arg, options) {
      var _ref2, n;
      this.config = _arg;
      options = (typeof options !== "undefined" && options !== null) ? options : {};
      this.size = 0;
      this.workers = [];
      this.readyWorkers = 0;
      this.idle = options.idle;
      this.stdout = new AggregateStream();
      this.stderr = new AggregateStream();
      _ref2 = options.size;
      for (n = 1; (1 <= _ref2 ? n <= _ref2 : n >= _ref2); (1 <= _ref2 ? n += 1 : n -= 1)) {
        this.increment();
      }
      return this;
    };
    __extends(Pool, EventEmitter);
    Pool.prototype.onNext = function(event, listener) {
      var callback;
      callback = __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        this.removeListener(event, callback);
        return listener.apply(this, args);
      }, this);
      return this.on(event, callback);
    };
    Pool.prototype.increment = function() {
      var process;
      this.size++;
      process = createProcess(this.config, {
        idle: this.idle
      });
      process.on('spawn', __bind(function() {
        this.stdout.add(process.stdout, process);
        return this.stderr.add(process.stderr, process);
      }, this));
      process.on('ready', __bind(function() {
        var previousReadyWorkers;
        previousReadyWorkers = this.readyWorkers;
        this.readyWorkers++;
        if (previousReadyWorkers === 0 && this.readyWorkers === 1) {
          this.emit('ready');
        }
        return this.emit('worker:ready');
      }, this));
      process.on('busy', __bind(function() {
        if (this.readyWorkers > 0) {
          this.readyWorkers--;
        }
        return this.emit('worker:busy');
      }, this));
      process.on('exit', __bind(function() {
        if (this.readyWorkers > 0) {
          this.readyWorkers--;
        }
        if (this.readyWorkers === 0) {
          this.emit('exit');
        }
        return this.emit('worker:exit');
      }, this));
      this.workers.push(process);
      return process;
    };
    Pool.prototype.decrement = function() {
      var worker;
      if (worker = this.workers.shift()) {
        this.size--;
        worker.quit();
        return worker;
      }
    };
    Pool.prototype.spawn = function() {
      var _i, _len, _ref2, _result, worker;
      _result = []; _ref2 = this.workers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        worker = _ref2[_i];
        _result.push(worker.spawn());
      }
      return _result;
    };
    Pool.prototype.quit = function() {
      var _result;
      _result = [];
      while (this.decrement()) {
        _result.push(true);
      }
      return _result;
    };
    Pool.prototype.proxyRequest = function(req, res, callback) {
      var worker;
      worker = this.workers.shift();
      return worker.proxyRequest(req, res, __bind(function() {
        if (typeof callback !== "undefined" && callback !== null) {
          callback();
        }
        return this.workers.unshift(worker);
      }, this));
    };
    return Pool;
  })();
  exports.createPool = function() {
    var _ctor, _ref2, _result, args;
    args = __slice.call(arguments, 0);
    return (function() {
      var ctor = function(){};
      __extends(ctor, _ctor = Pool);
      return typeof (_result = _ctor.apply(_ref2 = new ctor, args)) === "object" ? _result : _ref2;
    }).call(this);
  };
}).call(this);
