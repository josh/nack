(function() {
  var _ref, createPool, http;
  http = require('http');
  _ref = require('./pool');
  createPool = _ref.createPool;
  exports.createServer = function(config, options) {
    var pool, server;
    options = (typeof options !== "undefined" && options !== null) ? options : {};
    options.size = (typeof options.size !== "undefined" && options.size !== null) ? options.size : 3;
    options.idle = (typeof options.idle !== "undefined" && options.idle !== null) ? options.idle : (15 * 60 * 1000);
    pool = createPool(config, options);
    server = http.createServer(function(req, res, next) {
      return pool.proxyRequest(req, res, function(err) {
        if (err) {
          if (typeof next !== "undefined" && next !== null) {
            return next(err);
          } else {
            throw err;
          }
        }
      });
    });
    server.on('close', function() {
      return pool.quit();
    });
    server.pool = pool;
    return server;
  };
}).call(this);
