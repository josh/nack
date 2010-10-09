(function() {
  var _ref, createPool, createProcess, logStream;
  _ref = require('./process');
  createProcess = _ref.createProcess;
  _ref = require('./pool');
  createPool = _ref.createPool;
  _ref = require('./logger');
  logStream = _ref.logStream;
  module.exports = function(config, options) {
    var pool;
    options = (typeof options !== "undefined" && options !== null) ? options : {};
    options.size = (typeof options.size !== "undefined" && options.size !== null) ? options.size : 3;
    pool = createPool(config, options);
    return function(req, res, next) {
      return pool.proxyRequest(req, res, function(err) {
        return err ? next(err) : null;
      });
    };
  };
  module.exports.createProcess = createProcess;
  module.exports.createPool = createPool;
  module.exports.logStream = logStream;
}).call(this);
