(function() {
  var CRLF, EventEmitter, _a;
  _a = require('events');
  EventEmitter = _a.EventEmitter;
  CRLF = "\r\n";
  exports.Stream = function(client) {
    var buffer, stream;
    stream = new EventEmitter();
    buffer = "";
    client.on("data", function(chunk) {
      var _b, index, json;
      buffer += chunk;
      _b = [];
      while ((index = buffer.indexOf(CRLF)) !== -1) {
        _b.push((function() {
          json = buffer.slice(0, index);
          buffer = buffer.slice(index + CRLF.length, buffer.length);
          return stream.emit('obj', JSON.parse(json));
        })());
      }
      return _b;
    });
    return stream;
  };
})();
