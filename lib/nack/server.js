(function() {
  var createPool, createServer, dirname;
  createServer = require('connect').createServer;
  createPool = require('./pool').createPool;
  dirname = require('path').dirname;
  exports.createServer = function(config, options) {
    var origClose, pool, server, _ref, _ref2, _ref3;
    options != null ? options : options = {};
    (_ref = options.size) != null ? _ref : options.size = 3;
    (_ref2 = options.idle) != null ? _ref2 : options.idle = 15 * 60 * 1000;
    (_ref3 = options.cwd) != null ? _ref3 : options.cwd = dirname(config);
    pool = createPool(config, options);
    server = createServer(function(req, res, next) {
      return pool.proxyRequest(req, res, req.proxyMetaVariables, function(err) {
        if (err) {
          return next(err);
        }
      });
    });
    pool.on('error', function(error) {
      return server.emit('error', error);
    });
    origClose = server.close;
    server.close = function() {
      try {
        return origClose.apply(this);
      } catch (error) {
        if (error.message === "Not running") {
          return this.emit('close');
        } else {
          throw error;
        }
      }
    };
    server.on('close', function() {
      return pool.quit();
    });
    server.pool = pool;
    return server;
  };
}).call(this);
