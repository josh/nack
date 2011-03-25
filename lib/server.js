(function() {
  var createPool, createServer, dirname, http, poolEvents;
  var __slice = Array.prototype.slice;
  createServer = require('connect').createServer;
  createPool = require('./pool').createPool;
  dirname = require('path').dirname;
  http = require('http');
  poolEvents = ['error', 'ready', 'exit', 'worker:ready', 'worker:spawn', 'worker:busy', 'worker:exit'];
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
    poolEvents.forEach(function(type) {
      return pool.on(type, function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return server.emit.apply(server, [type].concat(__slice.call(args)));
      });
    });
    server.pool = pool;
    server.stdout = pool.stdout;
    server.stderr = pool.stderr;
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
    server.restart = function(callback) {
      if (pool.getAliveWorkerCount() === 0) {
        if (callback != null) {
          return callback();
        }
      } else {
        pool.once('worker:ready', function() {
          if (callback != null) {
            return callback();
          }
        });
        return pool.restart();
      }
    };
    return server;
  };
}).call(this);
