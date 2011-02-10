(function() {
  var Client, ClientRequest, ClientResponse, END_OF_FILE, Socket, Stream, assert, ns, url;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __slice = Array.prototype.slice;
  assert = require('assert');
  ns = require('./ns');
  url = require('url');
  Socket = require('net').Socket;
  Stream = require('stream').Stream;
  exports.Client = Client = (function() {
    __extends(Client, Socket);
    function Client() {
      var self;
      Client.__super__.constructor.apply(this, arguments);
      this._outgoing = [];
      this._incoming = null;
      self = this;
      this.on('connect', function() {
        return self._processRequest();
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
          this._incoming = new ClientResponse(this, request);
          return request.flush();
        }
      } else {
        return this.reconnect();
      }
    };
    Client.prototype._finishRequest = function() {
      var res;
      this._outgoing.shift();
      res = this._incoming;
      this._incoming = null;
      if (res === null || res.received === false) {
        this.emit('error', new Error("Response was not received"));
      } else if (res.completed === false && res.readable === true) {
        this.emit('error', new Error("Response was not completed"));
      }
      if (this._outgoing.length > 0) {
        return this._processRequest();
      }
    };
    Client.prototype.reconnect = function() {
      if (this.readyState === 'closed') {
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
      })(ClientRequest, [this].concat(__slice.call(args)), function() {});
      this._outgoing.push(request);
      this._processRequest();
      return request;
    };
    Client.prototype.proxyRequest = function(serverRequest, serverResponse, metaVariables) {
      var clientRequest, _ref, _ref2;
      if (metaVariables == null) {
        metaVariables = {};
      }
      (_ref = metaVariables["REMOTE_ADDR"]) != null ? _ref : metaVariables["REMOTE_ADDR"] = serverRequest.connection.remoteAddress;
      (_ref2 = metaVariables["REMOTE_PORT"]) != null ? _ref2 : metaVariables["REMOTE_PORT"] = serverRequest.connection.remotePort;
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
      clientRequest.on('error', function() {
        return serverRequest.destroy();
      });
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
    function ClientRequest(socket, method, path, headers, metaVariables) {
      this.socket = socket;
      this.method = method;
      this.path = path;
      this.writeable = true;
      this._writeQueue = [];
      this._parseEnv(headers, metaVariables);
      this.write(JSON.stringify(this.env));
    }
    ClientRequest.prototype._parseEnv = function(headers, metaVariables) {
      var host, key, name, pathname, port, query, value, _ref, _ref2, _results;
      this.env = {};
      this.env['REQUEST_METHOD'] = this.method;
      _ref = url.parse(this.path), pathname = _ref.pathname, query = _ref.query;
      this.env['PATH_INFO'] = pathname;
      this.env['QUERY_STRING'] = query;
      this.env['SCRIPT_NAME'] = "";
      this.env['REMOTE_ADDR'] = "0.0.0.0";
      this.env['SERVER_ADDR'] = "0.0.0.0";
      if (host = headers.host) {
        if (_ref2 = headers.host.split(':'), name = _ref2.name, port = _ref2.port, _ref2) {
          this.env['SERVER_NAME'] = name;
          this.env['SERVER_PORT'] = port;
        }
      }
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
    ClientRequest.prototype.write = function(chunk, encoding) {
      var nsChunk;
      nsChunk = ns.nsWrite(chunk, 0, chunk.length, null, 0, encoding);
      if (this._writeQueue) {
        this._writeQueue.push(nsChunk);
        return false;
      } else {
        return this.socket.write(nsChunk);
      }
    };
    ClientRequest.prototype.end = function(chunk, encoding) {
      var flushed;
      if (chunk) {
        this.write(chunk, encoding);
      }
      flushed = this._writeQueue ? (this._writeQueue.push(END_OF_FILE), false) : this.socket.end(END_OF_FILE);
      this.writeable = false;
      return flushed;
    };
    ClientRequest.prototype.destroy = function() {
      return this.socket.destroy();
    };
    ClientRequest.prototype.flush = function() {
      var data;
      while (this._writeQueue && this._writeQueue.length) {
        data = this._writeQueue.shift();
        if (data === END_OF_FILE) {
          this.socket.end(data);
        } else {
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
            return this.request.emit('response', this);
          } else if (data.length > 0) {
            return this.emit('data', data);
          }
        } else {
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
        this.readable = false;
        return this.socket.emit('error', error);
      }
    };
    ClientResponse.prototype._emit = ClientResponse.prototype.emit;
    ClientResponse.prototype.emit = function() {
      var args, type;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      type = args[0];
      if ((type === 'data' || type === 'end') && this._buffer) {
        return this._buffer.push(args);
      } else {
        return ClientResponse.__super__.emit.apply(this, arguments);
      }
    };
    ClientResponse.prototype.pause = function() {
      this._buffer = [];
      this.socket.pause();
      return this.emit('pause');
    };
    ClientResponse.prototype.resume = function() {
      var args;
      this.socket.resume();
      while (this._buffer && this._buffer.length) {
        args = this._buffer.shift();
        this._emit.apply(this, args);
      }
      this._buffer = null;
      return this.emit('resume');
    };
    return ClientResponse;
  })();
}).call(this);
