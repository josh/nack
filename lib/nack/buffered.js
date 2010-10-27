(function() {
  var BufferedLineStream, BufferedReadStream, EventEmitter, _ref;
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
  exports.BufferedReadStream = (function() {
    BufferedReadStream = function(_arg) {
      var _i, _ref2, name, queueEvent;
      this.stream = _arg;
      this.readable = true;
      this._queue = [];
      this._flushed = false;
      queueEvent = __bind(function(event) {
        var args;
        args = __slice.call(arguments, 1);
        return this._flushed ? this.emit.apply(this, [event].concat(args)) : this._queue.push(['emit', event].concat(args));
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
      this.stream.pause();
      _ref2 = this.stream;
      for (_i in _ref2) {
        (function() {
          var name = _i;
          var fun = _ref2[_i];
          if (!this[name] && name[0] !== '_') {
            this.__defineGetter__(name, function() {
              return this.stream[name];
            });
            return this.__defineSetter__(name, function(value) {
              return (this.stream[name] = value);
            });
          }
        }).call(this);
      }
      return this;
    };
    __extends(BufferedReadStream, EventEmitter);
    BufferedReadStream.prototype.resume = function() {};
    BufferedReadStream.prototype.pause = function() {};
    BufferedReadStream.prototype.destroy = function() {
      this._queue = [];
      return this.stream.destroy();
    };
    BufferedReadStream.prototype.flush = function() {
      var _i, _len, _ref2, _ref3, args, fun;
      try {
        this.stream.resume();
      } catch (error) {

      }
      _ref2 = this._queue;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        _ref3 = _ref2[_i];
        fun = _ref3[0];
        args = __slice.call(_ref3, 1);
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
