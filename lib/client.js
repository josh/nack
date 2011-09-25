(function() {
  var BufferedRequest, Client, ClientRequest, ClientResponse, Socket, Stream, assert, debug, fs, ns, url;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  assert = require('assert');
  fs = require('fs');
  ns = require('netstring');
  url = require('url');
  Socket = require('net').Socket;
  Stream = require('stream').Stream;
  debug = require('./util').debug;
  BufferedRequest = require('./util').BufferedRequest;
  exports.Client = Client = (function() {
    __extends(Client, Socket);
    function Client() {
      var self;
      Client.__super__.constructor.apply(this, arguments);
      debug("client created");
      this._outgoing = [];
      this._incoming = null;
      self = this;
      this.on('connect', function() {
        return self._processRequest();
      });
      this.on('error', function(err) {
        var req;
        if (req = self._outgoing[0]) {
          return req.emit('error', err);
        }
      });
      this.on('close', function() {
        return self._finishRequest();
      });
      this._initResponseParser();
    }
    Client.prototype._initResponseParser = function() {
      var nsStream, self;
      self = this;
      nsStream = new ns.Stream(this);
      nsStream.on('data', function(data) {
        if (self._incoming) {
          return self._incoming._receiveData(data);
        }
      });
      return nsStream.on('error', function(exception) {
        self._incoming = null;
        return self.emit('error', exception);
      });
    };
    Client.prototype._processRequest = function() {
      var request;
      if (this.readyState === 'open' && !this._incoming) {
        if (request = this._outgoing[0]) {
          debug("processing outgoing request 1/" + this._outgoing.length);
          this._incoming = new ClientResponse(this, request);
          request.pipe(this);
          return request.flush();
        }
      } else {
        return this.reconnect();
      }
    };
    Client.prototype._finishRequest = function() {
      var req, res;
      debug("finishing request");
      req = this._outgoing.shift();
      req.destroy();
      res = this._incoming;
      this._incoming = null;
      if (res === null || res.received === false) {
        req.emit('error', new Error("Response was not received"));
      } else if (res.readable && !res.statusCode) {
        req.emit('error', new Error("Missing status code"));
      } else if (res.readable && !res.headers) {
        req.emit('error', new Error("Missing headers"));
      }
      if (this._outgoing.length > 0) {
        return this._processRequest();
      }
    };
    Client.prototype.reconnect = function() {
      if (this.readyState === 'closed') {
        debug("connecting to " + this.port);
        return this.connect(this.port, this.host);
      }
    };
    Client.prototype.request = function() {
      var args, request;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      request = (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return typeof result === "object" ? result : child;
      })(ClientRequest, args, function() {});
      this._outgoing.push(request);
      this._processRequest();
      return request;
    };
    return Client;
  })();
  exports.createConnection = function(port, host) {
    var client;
    client = new Client;
    client.port = port;
    client.host = host;
    return client;
  };
  exports.ClientRequest = ClientRequest = (function() {
    __extends(ClientRequest, BufferedRequest);
    function ClientRequest() {
      ClientRequest.__super__.constructor.apply(this, arguments);
    }
    ClientRequest.prototype._buildEnv = function() {
      var env, host, key, parts, pathname, query, value, _ref, _ref2, _ref3, _ref4, _ref5;
      env = {};
      env['REQUEST_METHOD'] = this.method;
      _ref = url.parse(this.url), pathname = _ref.pathname, query = _ref.query;
      env['PATH_INFO'] = pathname;
      env['QUERY_STRING'] = query != null ? query : "";
      env['SCRIPT_NAME'] = "";
      env['REMOTE_ADDR'] = "0.0.0.0";
      env['SERVER_ADDR'] = "0.0.0.0";
      if (host = this.headers.host) {
        parts = this.headers.host.split(':');
        env['SERVER_NAME'] = parts[0];
        env['SERVER_PORT'] = parts[1];
      }
      if ((_ref2 = env['SERVER_NAME']) == null) {
        env['SERVER_NAME'] = "localhost";
      }
      if ((_ref3 = env['SERVER_PORT']) == null) {
        env['SERVER_PORT'] = "80";
      }
      _ref4 = this.headers;
      for (key in _ref4) {
        value = _ref4[key];
        key = key.toUpperCase().replace(/-/g, '_');
        if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
          key = "HTTP_" + key;
        }
        env[key] = value;
      }
      _ref5 = this.proxyMetaVariables;
      for (key in _ref5) {
        value = _ref5[key];
        env[key] = value;
      }
      return env;
    };
    ClientRequest.prototype.write = function(chunk, encoding) {
      return ClientRequest.__super__.write.call(this, ns.nsWrite(chunk, 0, chunk.length, null, 0, encoding));
    };
    ClientRequest.prototype.end = function(chunk, encoding) {
      if (chunk) {
        this.write(chunk, encoding);
      }
      return ClientRequest.__super__.end.call(this, "");
    };
    ClientRequest.prototype.flush = function() {
      var chunk, nsChunk;
      if (this._queue) {
        debug("requesting " + this.method + " " + this.url);
        chunk = JSON.stringify(this._buildEnv());
        nsChunk = ns.nsWrite(chunk, 0, chunk.length, null, 0, 'utf8');
        debug("writing header " + nsChunk.length + " bytes");
        this.emit('data', nsChunk);
      }
      return ClientRequest.__super__.flush.apply(this, arguments);
    };
    return ClientRequest;
  })();
  exports.ClientResponse = ClientResponse = (function() {
    __extends(ClientResponse, Stream);
    function ClientResponse(socket, request) {
      this.socket = socket;
      this.request = request;
      this.client = this.socket;
      this.readable = true;
      this.writable = true;
      this.received = false;
      this.completed = false;
      this.statusCode = null;
      this.httpVersion = '1.1';
      this.headers = null;
      this._buffer = null;
    }
    ClientResponse.prototype._receiveData = function(data) {
      var exception, k, rawHeaders, v, vs;
      debug("received " + data.length + " bytes");
      if (!this.readable || this.completed) {
        return;
      }
      this.received = true;
      try {
        if (data.length > 0) {
          if (!this.statusCode) {
            this.statusCode = parseInt(data);
            return assert.ok(this.statusCode >= 100, "Status must be >= 100");
          } else if (!this.headers) {
            this.headers = {};
            rawHeaders = JSON.parse(data);
            assert.ok(rawHeaders, "Headers can not be null");
            assert.equal(typeof rawHeaders, 'object', "Headers must be an object");
            for (k in rawHeaders) {
              vs = rawHeaders[k];
              if (vs.join) {
                vs = vs.join("\n");
              }
              v = vs.split("\n");
              this.headers[k] = v.length > 0 ? v.join("\r\n" + k + ": ") : vs;
            }
            debug("response received: " + this.statusCode);
            if (this._path = this.headers['X-Sendfile']) {
              delete this.headers['X-Sendfile'];
              return fs.stat(this._path, __bind(function(err, stat) {
                if (!stat.isFile()) {
                  err = new Error("" + this._path + " is not a file");
                }
                if (err) {
                  return this.onError(err);
                } else {
                  this.headers['Content-Length'] = "" + stat.size;
                  this.headers['Last-Modified'] = "" + (stat.mtime.toUTCString());
                  this.request.emit('response', this);
                  return fs.createReadStream(this._path).pipe(this);
                }
              }, this));
            } else {
              return this.request.emit('response', this);
            }
          } else if (data.length > 0 && !this._path) {
            return this.write(data);
          }
        } else if (!this._path) {
          return this.end();
        }
      } catch (error) {
        exception = (function() {
          try {
            return JSON.parse(data);
          } catch (_e) {}
        })();
        if (exception && exception.name && exception.message) {
          error = new Error(exception.message);
          error.name = exception.name;
          error.stack = exception.stack;
        }
        return this.onError(error);
      }
    };
    ClientResponse.prototype.onError = function(error) {
      debug("response error", error);
      this.readable = false;
      return this.socket.emit('error', error);
    };
    ClientResponse.prototype.write = function(data) {
      if (!this.readable || this.completed) {
        return;
      }
      return this.emit('data', data);
    };
    ClientResponse.prototype.end = function(data) {
      if (!this.readable || this.completed) {
        return;
      }
      if (data) {
        this.emit('data', data);
      }
      assert.ok(this.statusCode, "Missing status code");
      assert.ok(this.headers, "Missing headers");
      debug("response complete");
      this.readable = false;
      this.completed = true;
      return this.emit('end');
    };
    ClientResponse.prototype.pipe = function(dest, options) {
      if (dest.writeHead) {
        dest.useChunkedEncodingByDefault = false;
        dest.writeHead(this.statusCode, this.headers);
        dest.chunkedEncoding = false;
      }
      return ClientResponse.__super__.pipe.apply(this, arguments);
    };
    return ClientResponse;
  })();
}).call(this);
