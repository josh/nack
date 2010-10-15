(function() {
  var _ref, createPool, createServer, dirname;
  _ref = require('connect');
  createServer = _ref.createServer;
  _ref = require('./pool');
  createPool = _ref.createPool;
  _ref = require('path');
  dirname = _ref.dirname;
  exports.createServer = function(config, options) {
    var pool, server;
    options = (typeof options !== "undefined" && options !== null) ? options : {};
    options.size = (typeof options.size !== "undefined" && options.size !== null) ? options.size : 3;
    options.idle = (typeof options.idle !== "undefined" && options.idle !== null) ? options.idle : (15 * 60 * 1000);
    options.cwd = (typeof options.cwd !== "undefined" && options.cwd !== null) ? options.cwd : dirname(config);
    pool = createPool(config, options);
    server = createServer(function(req, res, next) {
      return pool.proxyRequest(req, res, function(err) {
        return err ? next(err) : null;
      });
    });
    server.on('close', function() {
      return pool.quit();
    });
    server.pool = pool;
    return server;
  };
}).call(this);
