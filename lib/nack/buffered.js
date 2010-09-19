(function() {
  var EventEmitter, WriteStream, _a;
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
  _a = require('events');
  EventEmitter = _a.EventEmitter;
  exports.WriteStream = (function() {
    WriteStream = function(_b) {
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
    __extends(WriteStream, EventEmitter);
    WriteStream.prototype.write = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (this._flushed) {
        return this.stream.write.apply(this.stream, args);
      } else {
        this._queue.push(['write'].concat(args));
        return false;
      }
    };
    WriteStream.prototype.end = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (this._flushed) {
        return this.stream.end.apply(this.stream, args);
      } else {
        this._queue.push(['end'].concat(args));
        return false;
      }
    };
    WriteStream.prototype.destroy = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (this._flushed) {
        return this.stream.destroy;
      } else {
        this._queue.push(['destroy'].concat(args));
        return false;
      }
    };
    WriteStream.prototype.flush = function() {
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
    return WriteStream;
  })();
})();
