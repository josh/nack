(function() {
  var _ref, createPool, createProcess, logStream;
  _ref = require('nack/process');
  createProcess = _ref.createProcess;
  _ref = require('nack/pool');
  createPool = _ref.createPool;
  _ref = require('nack/logger');
  logStream = _ref.logStream;
  exports.createProcess = createProcess;
  exports.createPool = createPool;
  exports.logStream = logStream;
}).call(this);
