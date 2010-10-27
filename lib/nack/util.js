(function() {
  var __slice = Array.prototype.slice;
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
      var _i, _len, _ref, args;
      _ref = queue;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        args = _ref[_i];
        stream.emit.apply(stream, args);
      }
      return stream.resume();
    };
  };
}).call(this);
