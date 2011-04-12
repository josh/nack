(function() {
  var Client, ClientRequest, ClientResponse, END_OF_FILE, Socket, Stream, assert, debug, ns, url;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice;
  assert = require('assert');
  ns = require('netstring');
  url = require('url');
  Socket = require('net').Socket;
  Stream = require('stream').Stream;
  debug = require('./util').debug;
  exports.Client = Client = (function() {
    __extends(Client, Socket);
    function Client() {
      this.proxy = __bind(this.proxy, this);;      var self;
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
          return request.assignSocket(this);
        }
      } else {
        return this.reconnect();
      }
    };
    Client.prototype._finishRequest = function() {
      var req, res;
      debug("finishing request");
      req = this._outgoing.shift();
      req.detachSocket(this);
      res = this._incoming;
      this._incoming = null;
      if (res === null || res.received === false) {
        req.emit('error', new Error("Response was not received"));
      } else if (res.completed === false && res.readable === true) {
        req.emit('error', new Error("Response was not completed"));
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
        return typeof result == "object" ? result : child;
      })(ClientRequest, args, function() {});
      this._outgoing.push(request);
      this._processRequest();
      return request;
    };
    Client.prototype.proxy = function(serverRequest, serverResponse, next) {
      var clientRequest, metaVariables, _ref, _ref2, _ref3;
      metaVariables = (_ref = serverRequest.proxyMetaVariables) != null ? _ref : {};
      (_ref2 = metaVariables['REMOTE_ADDR']) != null ? _ref2 : metaVariables['REMOTE_ADDR'] = "" + serverRequest.connection.remoteAddress;
      (_ref3 = metaVariables['REMOTE_PORT']) != null ? _ref3 : metaVariables['REMOTE_PORT'] = "" + serverRequest.connection.remotePort;
      clientRequest = this.request(serverRequest.method, serverRequest.url, serverRequest.headers, metaVariables);
      serverRequest.on('data', function(data) {
        return clientRequest.write(data);
      });
      serverRequest.on('end', function() {
        return clientRequest.end();
      });
      serverRequest.on('error', function() {
        return clientRequest.end();
      });
      clientRequest.on('error', next);
      clientRequest.on('response', function(clientResponse) {
        serverResponse.writeHead(clientResponse.statusCode, clientResponse.headers);
        return clientResponse.pipe(serverResponse);
      });
      return clientRequest;
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
  END_OF_FILE = ns.nsWrite("");
  exports.ClientRequest = ClientRequest = (function() {
    __extends(ClientRequest, Stream);
    function ClientRequest(method, path, headers, metaVariables) {
      this.method = method;
      this.path = path;
      debug("requesting " + this.method + " " + this.path);
      this.writeable = true;
      this._writeQueue = [];
      this._parseEnv(headers, metaVariables);
      this.write(JSON.stringify(this.env));
    }
    ClientRequest.prototype._parseEnv = function(headers, metaVariables) {
      var host, key, parts, pathname, query, value, _base, _base2, _ref, _ref2, _ref3, _results;
      this.env = {};
      this.env['REQUEST_METHOD'] = this.method;
      _ref = url.parse(this.path), pathname = _ref.pathname, query = _ref.query;
      this.env['PATH_INFO'] = pathname;
      this.env['QUERY_STRING'] = query != null ? query : "";
      this.env['SCRIPT_NAME'] = "";
      this.env['REMOTE_ADDR'] = "0.0.0.0";
      this.env['SERVER_ADDR'] = "0.0.0.0";
      if (host = headers.host) {
        parts = headers.host.split(':');
        this.env['SERVER_NAME'] = parts[0];
        this.env['SERVER_PORT'] = parts[1];
      }
      (_ref2 = (_base = this.env)['SERVER_NAME']) != null ? _ref2 : _base['SERVER_NAME'] = "localhost";
      (_ref3 = (_base2 = this.env)['SERVER_PORT']) != null ? _ref3 : _base2['SERVER_PORT'] = "80";
      for (key in headers) {
        value = headers[key];
        key = key.toUpperCase().replace(/-/g, '_');
        if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
          key = "HTTP_" + key;
        }
        this.env[key] = value;
      }
      _results = [];
      for (key in metaVariables) {
        value = metaVariables[key];
        _results.push(this.env[key] = value);
      }
      return _results;
    };
    ClientRequest.prototype.assignSocket = function(socket) {
      debug("socket assigned, flushing request");
      this.socket = this.connection = socket;
      return this._flush();
    };
    ClientRequest.prototype.detachSocket = function(socket) {
      this.writeable = false;
      return this.socket = this.connection = null;
    };
    ClientRequest.prototype.write = function(chunk, encoding) {
      var nsChunk;
      nsChunk = ns.nsWrite(chunk, 0, chunk.length, null, 0, encoding);
      if (this._writeQueue) {
        debug("queueing " + nsChunk.length + " bytes");
        this._writeQueue.push(nsChunk);
        return false;
      } else if (this.connection) {
        debug("writing " + nsChunk.length + " bytes");
        return this.connection.write(nsChunk);
      }
    };
    ClientRequest.prototype.end = function(chunk, encoding) {
      var flushed;
      if (chunk) {
        this.write(chunk, encoding);
      }
      flushed = this._writeQueue ? (debug("queueing close"), this._writeQueue.push(END_OF_FILE), false) : this.connection ? (debug("closing connection"), this.connection.end(END_OF_FILE)) : void 0;
      this.detachSocket(this.socket);
      return flushed;
    };
    ClientRequest.prototype.destroy = function() {
      this.detachSocket(this.socket);
      return this.socket.destroy();
    };
    ClientRequest.prototype._flush = function() {
      var data;
      while (this._writeQueue && this._writeQueue.length) {
        data = this._writeQueue.shift();
        if (data === END_OF_FILE) {
          this.socket.end(data);
        } else {
          debug("flushing " + data.length + " bytes");
          this.socket.write(data);
        }
      }
      this._writeQueue = null;
      this.emit('drain');
      return true;
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
      this.received = false;
      this.completed = false;
      this.statusCode = null;
      this.httpVersion = '1.1';
      this.headers = null;
      this._buffer = null;
    }
    ClientResponse.prototype._receiveData = function(data) {
      var error, exception, k, rawHeaders, v, vs;
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
              v = vs.split("\n");
              this.headers[k] = v.length > 0 ? v.join("\r\n" + k + ": ") : vs;
            }
            debug("response received: " + this.statusCode);
            return this.request.emit('response', this);
          } else if (data.length > 0) {
            return this.emit('data', data);
          }
        } else {
          debug("response complete");
          assert.ok(this.statusCode, "Missing status code");
          assert.ok(this.headers, "Missing headers");
          this.readable = false;
          this.completed = true;
          return this.emit('end');
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
        debug("response error", error);
        this.readable = false;
        return this.socket.emit('error', error);
      }
    };
    return ClientResponse;
  })();
}).call(this);
