(function() {
  var EventEmitter, Pool, _a, _b, createProcess;
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
  exports.Pool = (function() {
    Pool = function(_c, size) {
      var n;
      this.config = _c;
      this.size = 0;
      this.workers = [];
      this.readyWorkers = 0;
      for (n = 1; (1 <= size ? n <= size : n >= size); (1 <= size ? n += 1 : n -= 1)) {
        this.increment();
      }
      this.on('worker:ready', __bind(function() {
        this.readyWorkers++;
        if (this.readyWorkers === 1) {
          this.emit('ready');
        }
        return this.readyWorkers === this.size ? this.emit('allready') : null;
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
      process = createProcess(this.config);
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
        return this.workers.push(worker);
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
