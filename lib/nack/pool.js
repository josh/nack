(function() {
  var AggregateStream, BufferedReadStream, EventEmitter, Pool, _ref, createProcess;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __slice = Array.prototype.slice, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  };
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  _ref = require('./process');
  createProcess = _ref.createProcess;
  _ref = require('./buffered');
  BufferedReadStream = _ref.BufferedReadStream;
  exports.Pool = (function() {
    Pool = function(_arg, options) {
      var _ref2, n, previousReadyWorkerCount;
      this.config = _arg;
      options = (typeof options !== "undefined" && options !== null) ? options : {};
      options.size = (typeof options.size !== "undefined" && options.size !== null) ? options.size : 1;
      this.workers = [];
      this.processOptions = {
        idle: options.idle,
        cwd: options.cwd
      };
      this.stdout = new AggregateStream();
      this.stderr = new AggregateStream();
      previousReadyWorkerCount = 0;
      this.on('worker:ready', __bind(function() {
        var newReadyWorkerCount;
        newReadyWorkerCount = this.getReadyWorkerCount();
        if (previousReadyWorkerCount === 0 && newReadyWorkerCount > 0) {
          this.emit('ready');
        }
        return (previousReadyWorkerCount = newReadyWorkerCount);
      }, this));
      this.on('worker:exit', __bind(function() {
        return this.getAliveWorkerCount() === 0 ? this.emit('exit') : null;
      }, this));
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
    Pool.prototype.getAliveWorkerCount = function() {
      var _i, _len, _ref2, count, worker;
      count = 0;
      _ref2 = this.workers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        worker = _ref2[_i];
        if (worker.state) {
          count++;
        }
      }
      return count;
    };
    Pool.prototype.getReadyWorkerCount = function() {
      var _i, _len, _ref2, count, worker;
      count = 0;
      _ref2 = this.workers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        worker = _ref2[_i];
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
      return (worker = this.workers.shift()) ? worker.quit() : null;
    };
    Pool.prototype.announceReadyWorkers = function() {
      var _i, _len, _ref2, _result, oneReady;
      oneReady = false;
      _result = []; _ref2 = this.workers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        (function() {
          var worker = _ref2[_i];
          return _result.push((function() {
            if (worker.state === 'ready') {
              oneReady = true;
              return process.nextTick(__bind(function() {
                return this.emit('worker:ready', worker);
              }, this));
            } else if (oneReady === false && !worker.state) {
              oneReady = true;
              return process.nextTick(function() {
                return worker.spawn();
              });
            }
          }).call(this));
        }).call(this);
      }
      return _result;
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
    Pool.prototype.terminate = function() {
      var _i, _len, _ref2, _result, worker;
      _result = []; _ref2 = this.workers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        worker = _ref2[_i];
        _result.push(worker.terminate());
      }
      return _result;
    };
    Pool.prototype.quit = function() {
      var _i, _len, _ref2, _result, worker;
      _result = []; _ref2 = this.workers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        worker = _ref2[_i];
        _result.push(worker.quit());
      }
      return _result;
    };
    Pool.prototype.proxyRequest = function(req, res, callback) {
      var reqBuf;
      reqBuf = new BufferedReadStream(req);
      this.onNext('worker:ready', function(worker) {
        return worker.createConnection(function(connection) {
          connection.proxyRequest(reqBuf, res);
          if (callback) {
            connection.on('error', callback);
            connection.on('close', callback);
          }
          return reqBuf.flush();
        });
      });
      return this.announceReadyWorkers();
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
}).call(this);
