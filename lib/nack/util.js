(function() {
  var EventEmitter, LineBuffer, _ref;
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
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  exports.pause = function(stream) {
    var queue;
    queue = [];
    stream.pause();
    stream.on('data', function() {
      var args;
      args = __slice.call(arguments, 0);
      return queue.push(['data'].concat(args));
    });
    stream.on('end', function() {
      var args;
      args = __slice.call(arguments, 0);
      return queue.push(['end'].concat(args));
    });
    return function() {
      var _i, _len, _ref2, args;
      _ref2 = queue;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        args = _ref2[_i];
        stream.emit.apply(stream, args);
      }
      return stream.resume();
    };
  };
  exports.LineBuffer = (function() {
    LineBuffer = function(_arg) {
      this.stream = _arg;
      this.readable = true;
      this._buffer = "";
      this.stream.on('data', __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        return this.write.apply(this, args);
      }, this));
      this.stream.on('end', __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        return this.end.apply(this, args);
      }, this));
      return this;
    };
    __extends(LineBuffer, EventEmitter);
    LineBuffer.prototype.write = function(chunk) {
      var _result, index, line;
      this._buffer += chunk;
      _result = [];
      while ((index = this._buffer.indexOf("\n")) !== -1) {
        _result.push((function() {
          line = this._buffer.slice(0, index);
          this._buffer = this._buffer.slice(index + 1, this._buffer.length);
          return this.emit('data', line);
        }).call(this));
      }
      return _result;
    };
    LineBuffer.prototype.end = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (args.length > 0) {
        this.write.apply(this, args);
      }
      return this.emit('end');
    };
    return LineBuffer;
  })();
}).call(this);
