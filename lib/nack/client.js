(function() {
  var Client, ClientRequest, ClientResponse, END_OF_FILE, EventEmitter, Stream, assert, ns, url, util;
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
  util = require(process.binding('natives').util ? 'util' : 'sys');
  url = require('url');
  Stream = require('net').Stream;
  EventEmitter = require('events').EventEmitter;
  exports.Client = Client = function() {
    function Client() {
      var self;
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
    __extends(Client, Stream);
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
    Client.prototype.proxyRequest = function(serverRequest, serverResponse) {
      var clientRequest, metaVariables;
      metaVariables = {
        "REMOTE_ADDR": serverRequest.connection.remoteAddress,
        "REMOTE_PORT": serverRequest.connection.remotePort
      };
      clientRequest = this.request(serverRequest.method, serverRequest.url, serverRequest.headers, metaVariables);
      util.pump(serverRequest, clientRequest);
      clientRequest.on("response", function(clientResponse) {
        serverResponse.writeHead(clientResponse.statusCode, clientResponse.headers);
        return util.pump(clientResponse, serverResponse);
      });
      return clientRequest;
    };
    return Client;
  }();
  exports.createConnection = function(port, host) {
    var client;
    client = new Client;
    client.port = port;
    client.host = host;
    return client;
  };
  END_OF_FILE = ns.nsWrite("");
  exports.ClientRequest = ClientRequest = function() {
    function ClientRequest(socket, method, path, headers, metaVariables) {
      this.socket = socket;
      this.method = method;
      this.path = path;
      this.writeable = true;
      this._writeQueue = [];
      this._parseEnv(headers, metaVariables);
      this.write(JSON.stringify(this.env));
    }
    __extends(ClientRequest, EventEmitter);
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
        if (!__hasProp.call(headers, key)) continue;
        value = headers[key];
        key = key.toUpperCase().replace(/-/g, '_');
        if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
          key = "HTTP_" + key;
        }
        this.env[key] = value;
      }
      _results = [];
      for (key in metaVariables) {
        if (!__hasProp.call(metaVariables, key)) continue;
        value = metaVariables[key];
        _results.push(this.env[key] = value);
      }
      return _results;
    };
    ClientRequest.prototype.write = function(chunk) {
      var nsChunk;
      nsChunk = ns.nsWrite(chunk);
      if (this._writeQueue) {
        this._writeQueue.push(nsChunk);
        return false;
      } else {
        return this.socket.write(nsChunk);
      }
    };
    ClientRequest.prototype.end = function(chunk) {
      var flushed;
      if (chunk) {
        this.write(chunk);
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
  }();
  exports.ClientResponse = ClientResponse = function() {
    function ClientResponse(socket, request) {
      this.socket = socket;
      this.request = request;
      this.client = this.socket;
      this.readable = true;
      this.received = false;
      this.completed = false;
      this.statusCode = null;
      this.headers = null;
    }
    __extends(ClientResponse, EventEmitter);
    ClientResponse.prototype._receiveData = function(data) {
      var k, rawHeaders, v, vs;
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
            assert.equal(typeof rawHeaders, 'object', "Headers must be an object");
            for (k in rawHeaders) {
              if (!__hasProp.call(rawHeaders, k)) continue;
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
        this.readable = false;
        return this.socket.emit('error', error);
      }
    };
    return ClientResponse;
  }();
}).call(this);
