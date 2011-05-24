(function() {
  var createPool, createServer;
  createServer = require('connect').createServer;
  createPool = require('./pool').createPool;
  exports.createServer = function(config, options) {
    var pool, server, _ref, _ref2;
        if (options != null) {
      options;
    } else {
      options = {};
    };
        if ((_ref = options.size) != null) {
      _ref;
    } else {
      options.size = 3;
    };
        if ((_ref2 = options.idle) != null) {
      _ref2;
    } else {
      options.idle = 15 * 60 * 1000;
    };
    pool = createPool(config, options);
    server = createServer(pool.proxy);
    server.on('close', function() {
      return pool.quit();
    });
    return server;
  };
}).call(this);
