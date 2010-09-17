(function() {
  var CRLF, EventEmitter, StreamParser, _a;
  var __bind = function(func, context) {
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
  CRLF = "\r\n";
  exports.StreamParser = (function() {
    StreamParser = function(stream) {
      var buffer;
      buffer = "";
      stream.on('data', __bind(function(chunk) {
        var _b, index, json;
        buffer += chunk;
        _b = [];
        while ((index = buffer.indexOf(CRLF)) !== -1) {
          _b.push((function() {
            json = buffer.slice(0, index);
            buffer = buffer.slice(index + CRLF.length, buffer.length);
            return this.emit('obj', JSON.parse(json));
          }).call(this));
        }
        return _b;
      }, this));
      return this;
    };
    __extends(StreamParser, EventEmitter);
    return StreamParser;
  })();
})();
