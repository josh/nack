(function() {
  var EventEmitter, ReadStream, _ref;
  var __slice = Array.prototype.slice, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  };
  exports.length = function(buf) {
    var byte, i, len;
    len = (i = 0);
    while (i < buf.length) {
      byte = buf[i];
      if (byte === 0x3a) {
        if (i === 0) {
          throw new Error("Invalid netstring with leading ':'");
        } else {
          return len;
        }
      }
      if (byte < 0x30 || byte > 0x39) {
        throw new Error("Unexpected character '" + (String.fromCharCode(buf[i])) + "' found at offset " + (i));
      }
      if (len === 0 && i > 0) {
        throw new Error("Invalid netstring with leading 0");
      }
      len = len * 10 + byte - 0x30;
      i++;
    }
    return i === buf.length ? false : len;
  };
  exports.decode = function(buffer) {
    var end, len, offset;
    if (typeof buffer === 'string') {
      buffer = new Buffer(buffer);
    }
    len = exports.length(buffer);
    if (len === false) {
      return false;
    }
    offset = ("" + (len) + ":").length;
    end = offset + len;
    return buffer.length < end ? false : buffer.slice(offset, end);
  };
  exports.encode = function(buffer) {
    return new Buffer("" + (buffer.length) + ":" + (buffer) + ",");
  };
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  exports.ReadStream = (function() {
    ReadStream = function(_arg) {
      var _i, _ref2, name;
      this.stream = _arg;
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
    __extends(ReadStream, EventEmitter);
    ReadStream.prototype.on = function(event, listener) {
      var buffer;
      if (event === 'data') {
        buffer = "";
        return this.stream.on('data', function(chunk) {
          var _result, buf, offset;
          buffer += chunk;
          _result = [];
          while (buf = exports.decode(buffer)) {
            _result.push((function() {
              offset = exports.encode(buf).length;
              buffer = buffer.slice(offset, offset + buffer.length);
              return listener(buf);
            })());
          }
          return _result;
        });
      } else {
        return this.stream.on(event, listener);
      }
    };
    return ReadStream;
  })();
}).call(this);
