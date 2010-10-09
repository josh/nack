(function() {
  var BufferedLineStream, Logger, _ref, chomp, sys;
  sys = require('sys');
  _ref = require('./buffered');
  BufferedLineStream = _ref.BufferedLineStream;
  chomp = function(str) {
    return str.replace(/(\n|\r)+$/, '');
  };
  exports.Logger = (function() {
    Logger = function(stream, log) {
      stream = new BufferedLineStream(stream);
      log = (typeof log !== "undefined" && log !== null) ? log : sys.log;
      stream.on('data', function(line) {
        return log(chomp(line));
      });
      return this;
    };
    return Logger;
  })();
  exports.logStream = function(stream) {
    return new Logger(stream);
  };
}).call(this);
