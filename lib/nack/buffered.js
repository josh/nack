(function() {
  var BufferedLineStream, EventEmitter, _ref;
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
  exports.BufferedLineStream = (function() {
    BufferedLineStream = function(_arg) {
      var _i, _ref2, name;
      this.stream = _arg;
      this.readable = true;
      this._buffer = "";
      this._flushed = false;
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
      this.stream.on('error', __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        return this.emit.apply(this, ['error'].concat(args));
      }, this));
      this.stream.on('close', __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        return this.emit.apply(this, ['close'].concat(args));
      }, this));
      this.stream.on('fd', __bind(function() {
        var args;
        args = __slice.call(arguments, 0);
        return this.emit.apply(this, ['fd'].concat(args));
      }, this));
      _ref2 = this.stream;
      for (_i in _ref2) {
        (function() {
          var name = _i;
          var fun = _ref2[_i];
          return !this[name] && name[0] !== '_' ? this.__defineGetter__(name, function() {
            var args;
            args = __slice.call(arguments, 0);
            return this.stream[name];
          }) : null;
        }).call(this);
      }
      return this;
    };
    __extends(BufferedLineStream, EventEmitter);
    BufferedLineStream.prototype.write = function(chunk) {
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
    BufferedLineStream.prototype.end = function() {
      var args;
      args = __slice.call(arguments, 0);
      if (args.length > 0) {
        this.write.apply(this, args);
      }
      return this.emit('end');
    };
    return BufferedLineStream;
  })();
}).call(this);
