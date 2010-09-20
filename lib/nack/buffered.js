(function() {
  var BufferedReadStream, BufferedWriteStream, EventEmitter, _a;
  var __slice = Array.prototype.slice, __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  };
  _a = require('events');
  EventEmitter = _a.EventEmitter;
  exports.BufferedReadStream = (function() {
    BufferedReadStream = function(_b) {
      var _c, _d, name, queueEvent;
      this.stream = _b;
      this.readable = true;
      this._queue = [];
      this._flushed = false;
      queueEvent = __bind(function(event) {
        var args;
        args = __slice.call(arguments, 1);
        return this._flushed ? this.emit.apply(this, args) : this._queue.push(['emit', event].concat(args));
      }, this);
      this.stream.on('data', function() {
        var args;
        args = __slice.call(arguments, 0);
        return queueEvent.apply(this, ['data'].concat(args));
      });
      this.stream.on('end', function() {
        var args;
        args = __slice.call(arguments, 0);
        return queueEvent.apply(this, ['end'].concat(args));
      });
      this.stream.on('error', function() {
        var args;
        args = __slice.call(arguments, 0);
        return queueEvent.apply(this, ['error'].concat(args));
      });
      this.stream.on('close', function() {
        var args;
        args = __slice.call(arguments, 0);
        return queueEvent.apply(this, ['close'].concat(args));
      });
      this.stream.on('fd', function() {
        var args;
        args = __slice.call(arguments, 0);
        return queueEvent.apply(this, ['fd'].concat(args));
      });
      this.stream.pause();
      _d = this.stream;
      for (_c in _d) {
        (function() {
          var name = _c;
          var fun = _d[_c];
          return !this[name] && name[0] !== '_' ? this.__defineGetter__(name, function() {
            var args;
            args = __slice.call(arguments, 0);
            return this.stream[name];
          }) : null;
        }).call(this);
      }
      return this;
    };
    __extends(BufferedReadStream, EventEmitter);
    BufferedReadStream.prototype.resume = function() {};
    BufferedReadStream.prototype.pause = function() {};
    BufferedReadStream.prototype.flush = function() {
      var _b, _c, _d, _e, args, fun;
      try {
        this.stream.resume();
      } catch (error) {

      }
      _c = this._queue;
      for (_b = 0, _e = _c.length; _b < _e; _b++) {
        _d = _c[_b];
        fun = _d[0];
        args = __slice.call(_d, 1);
        switch (fun) {
        case 'emit':
          this.emit.apply(this, args);
          break;
        }
      }
      this._flushed = true;
      return this.emit('drain');
    };
    return BufferedReadStream;
  })();
  exports.BufferedWriteStream = (function() {
    BufferedWriteStream = function(_b) {
      this.stream = _b;
      this.writeable = true;
      this._queue = [];
      this._flushed = false;
      this.stream.on('drain', __bind(function() {
        return this.emit('drain');
      }, this));
      this.stream.on('error', __bind(function(exception) {
        return this.emit('error', exception);
      }, this));
      this.stream.on('close', __bind(function() {
        return this.emit('close');
      }, this));
      return this;
    };
    __extends(BufferedWriteStream, EventEmitter);
    BufferedWriteStream.prototype.write = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (this._flushed) {
        return this.stream.write.apply(this.stream, args);
      } else {
        this._queue.push(['write'].concat(args));
        return false;
      }
    };
    BufferedWriteStream.prototype.end = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (this._flushed) {
        return this.stream.end.apply(this.stream, args);
      } else {
        this._queue.push(['end'].concat(args));
        return false;
      }
    };
    BufferedWriteStream.prototype.destroy = function() {
      if (this._flushed) {
        return this.stream.destroy();
      } else {
        this._queue.push(['destroy']);
        return false;
      }
    };
    BufferedWriteStream.prototype.flush = function() {
      var _b, _c, _d, _e, args, fun;
      _c = this._queue;
      for (_b = 0, _e = _c.length; _b < _e; _b++) {
        _d = _c[_b];
        fun = _d[0];
        args = __slice.call(_d, 1);
        switch (fun) {
        case 'write':
          this.stream.write.apply(this.stream, args);
          break;
        case 'end':
          this.stream.end.apply(this.stream, args);
          break;
        case 'destroy':
          this.stream.destroy.apply(this.stream, args);
          break;
        }
      }
      this._flushed = true;
      return this.emit('drain');
    };
    return BufferedWriteStream;
  })();
})();
