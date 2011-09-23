(function() {
  var LineBuffer, Stream;
  var __slice = Array.prototype.slice, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  Stream = require('stream').Stream;
  if (process.env.NODE_DEBUG && /nack/.test(process.env.NODE_DEBUG)) {
    exports.debug = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return console.error.apply(console, ['NACK:'].concat(__slice.call(args)));
    };
  } else {
    exports.debug = function() {};
  }
  exports.isFunction = function(obj) {
    if (obj && obj.constructor && obj.call && obj.apply) {
      return true;
    } else {
      return false;
    }
  };
  exports.pause = function(stream) {
    var dataListeners, listener, onClose, onData, onEnd, queue, removeListeners, _i, _len, _ref;
    queue = [];
    dataListeners = [];
    _ref = stream.listeners('data');
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      listener = _ref[_i];
      dataListeners.push(listener);
    }
    stream.removeAllListeners('data');
    onData = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return queue.push(['data'].concat(__slice.call(args)));
    };
    onEnd = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return queue.push(['end'].concat(__slice.call(args)));
    };
    onClose = function() {
      return removeListeners();
    };
    removeListeners = function() {
      stream.removeListener('data', onData);
      stream.removeListener('end', onEnd);
      return stream.removeListener('close', onClose);
    };
    stream.on('data', onData);
    stream.on('end', onEnd);
    stream.on('close', onClose);
    return function() {
      var args, listener, _j, _k, _len2, _len3, _results;
      removeListeners();
      for (_j = 0, _len2 = dataListeners.length; _j < _len2; _j++) {
        listener = dataListeners[_j];
        stream.on('data', listener);
      }
      _results = [];
      for (_k = 0, _len3 = queue.length; _k < _len3; _k++) {
        args = queue[_k];
        _results.push(stream.emit.apply(stream, args));
      }
      return _results;
    };
  };
  exports.LineBuffer = LineBuffer = (function() {
    __extends(LineBuffer, Stream);
    function LineBuffer(stream) {
      var self;
      this.stream = stream;
      this.readable = true;
      this._buffer = "";
      self = this;
      this.stream.on('data', function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return self.write.apply(self, args);
      });
      this.stream.on('end', function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return self.end.apply(self, args);
      });
    }
    LineBuffer.prototype.write = function(chunk) {
      var index, line, _results;
      this._buffer += chunk;
      _results = [];
      while ((index = this._buffer.indexOf("\n")) !== -1) {
        line = this._buffer.slice(0, index);
        this._buffer = this._buffer.slice(index + 1, this._buffer.length);
        _results.push(this.emit('data', line));
      }
      return _results;
    };
    LineBuffer.prototype.end = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (args.length > 0) {
        this.write.apply(this, args);
      }
      return this.emit('end');
    };
    return LineBuffer;
  })();
}).call(this);
