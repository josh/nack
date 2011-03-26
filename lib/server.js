(function() {
  var createPool, createServer;
  createServer = require('connect').createServer;
  createPool = require('./pool').createPool;
  exports.createServer = function(config, options) {
    var pool, server, _ref, _ref2;
    options != null ? options : options = {};
    (_ref = options.size) != null ? _ref : options.size = 3;
    (_ref2 = options.idle) != null ? _ref2 : options.idle = 15 * 60 * 1000;
    pool = createPool(config, options);
    server = createServer(pool.proxy);
    server.on('close', function() {
      return pool.quit();
    });
    return server;
  };
}).call(this);
