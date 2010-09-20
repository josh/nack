(function() {
  var AggregateStream, EventEmitter, Pool, _a, _b, createProcess;
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
  _a = require('events');
  EventEmitter = _a.EventEmitter;
  _b = require('nack/process');
  createProcess = _b.createProcess;
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
    Pool = function(_c, options) {
      var _d, n;
      this.config = _c;
      options = (typeof options !== "undefined" && options !== null) ? options : {};
      this.size = 0;
      this.workers = [];
      this.readyWorkers = 0;
      this.idle = options.idle;
      this.stdout = new AggregateStream();
      this.stderr = new AggregateStream();
      _d = options.size;
      for (n = 1; (1 <= _d ? n <= _d : n >= _d); (1 <= _d ? n += 1 : n -= 1)) {
        this.increment();
      }
      this.on('worker:ready', __bind(function() {
        this.readyWorkers++;
        return this.readyWorkers === 1 ? this.emit('ready') : null;
      }, this));
      this.on('worker:exit', __bind(function() {
        if (this.readyWorkers > 0) {
          this.readyWorkers--;
        }
        return this.readyWorkers === 0 ? this.emit('exit') : null;
      }, this));
      return this;
    };
    __extends(Pool, EventEmitter);
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
        return this.emit('worker:ready');
      }, this));
      process.on('exit', __bind(function() {
        return this.emit('worker:exit');
      }, this));
      this.workers.push(process);
      return process;
    };
    Pool.prototype.decrement = function() {
      this.size--;
      return this.workers.shift();
    };
    Pool.prototype.spawn = function() {
      var _c, _d, _e, _f, worker;
      _c = []; _e = this.workers;
      for (_d = 0, _f = _e.length; _d < _f; _d++) {
        worker = _e[_d];
        _c.push(worker.spawn());
      }
      return _c;
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
    Pool.prototype.quit = function() {
      var _c, _d, _e, _f, worker;
      _c = []; _e = this.workers;
      for (_d = 0, _f = _e.length; _d < _f; _d++) {
        worker = _e[_d];
        _c.push(worker.quit());
      }
      return _c;
    };
    return Pool;
  })();
  exports.createPool = function() {
    var _c, _d, _e, args;
    args = __slice.call(arguments, 0);
    return (function() {
      var ctor = function(){};
      __extends(ctor, _c = Pool);
      return typeof (_d = _c.apply(_e = new ctor, args)) === "object" ? _d : _e;
    }).call(this);
  };
})();
