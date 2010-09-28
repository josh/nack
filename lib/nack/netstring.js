(function() {
  var EventEmitter, ReadStream, _ref, concatBuffers;
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
    return i === buf.length ? -1 : len;
  };
  exports.nsLength = function(buf) {
    var length, nsHeader;
    length = buf.length;
    nsHeader = ("" + (length) + ":");
    return nsHeader.length + length + 1;
  };
  exports.decode = function(buffer) {
    var end, length, nsHeader, offset;
    if (typeof buffer === 'string') {
      buffer = new Buffer(buffer);
    }
    length = exports.length(buffer);
    if (length === -1) {
      return -1;
    }
    nsHeader = ("" + (length) + ":");
    offset = nsHeader.length;
    end = offset + length;
    return buffer.length < end ? -1 : buffer.slice(offset, end);
  };
  exports.encode = function(buffer) {
    var length, nsHeader, nsLength, out;
    if (typeof buffer === 'string') {
      buffer = new Buffer(buffer);
    }
    length = buffer.length;
    nsHeader = ("" + (length) + ":");
    nsLength = nsHeader.length + length + 1;
    out = new Buffer(nsLength);
    out.write(nsHeader, 0);
    buffer.copy(out, nsHeader.length, 0);
    out.write(",", nsLength - 1);
    return out;
  };
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  concatBuffers = function(buf1, buf2) {
    var buf, len;
    len = buf1.length + buf2.length;
    buf = new Buffer(len);
    buf1.copy(buf, 0, 0);
    buf2.copy(buf, buf1.length, 0);
    return buf;
  };
  exports.ReadStream = (function() {
    ReadStream = function(_arg) {
      var _i, _ref2, buffer, name;
      this.stream = _arg;
      buffer = new Buffer(0);
      this.stream.on('data', __bind(function(chunk) {
        var _result, buf, offset;
        buffer = concatBuffers(buffer, chunk);
        _result = [];
        while (true) {
          try {
            buf = exports.decode(buffer);
            if (buf === -1) {
              break;
            }
            offset = exports.nsLength(buf);
            buffer = buffer.slice(offset, buffer.length);
            this.emit('string', buf);
          } catch (error) {
            this.emit('error', error);
            break;
          }
        }
        return _result;
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
    __extends(ReadStream, EventEmitter);
    return ReadStream;
  })();
}).call(this);
