(function() {
  var Client, ClientRequest, ClientResponse, END_OF_FILE, EventEmitter, Stream, _ref, ns, sys, url;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __slice = Array.prototype.slice, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  }, __hasProp = Object.prototype.hasOwnProperty;
  sys = require('sys');
  url = require('url');
  ns = require('./ns');
  _ref = require('net');
  Stream = _ref.Stream;
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  exports.Client = (function() {
    Client = function() {
      this._outgoing = [];
      this._incoming = null;
      this.on('connect', __bind(function() {
        return this._processRequest();
      }, this));
      this.on('close', __bind(function() {
        return this._finishRequest();
      }, this));
      this._initResponseParser();
      return this;
    };
    __extends(Client, Stream);
    Client.prototype._initResponseParser = function() {
      var nsStream;
      nsStream = new ns.Stream(this);
      nsStream.on('data', __bind(function(data) {
        return this._incoming ? this._incoming._receiveData(data) : null;
      }, this));
      return nsStream.on('error', __bind(function(exception) {
        this._incoming = null;
        return this.emit('error', exception);
      }, this));
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
      this._outgoing.shift();
      if (this._incoming.finished === false) {
        this.emit('error', new Error("Incomplete request"));
      }
      this._incoming = null;
      return this._outgoing.length > 0 ? this._processRequest() : null;
    };
    Client.prototype.reconnect = function() {
      return this.readyState === 'closed' ? this.connect(this.port, this.host) : null;
    };
    Client.prototype.request = function() {
      var _ctor, _ref2, _result, args, request;
      args = __slice.call(arguments, 0);
      request = (function() {
        var ctor = function(){};
        __extends(ctor, _ctor = ClientRequest);
        return typeof (_result = _ctor.apply(_ref2 = new ctor, [this].concat(args))) === "object" ? _result : _ref2;
      }).call(this);
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
      sys.pump(serverRequest, clientRequest);
      clientRequest.on("response", function(clientResponse) {
        serverResponse.writeHead(clientResponse.statusCode, clientResponse.headers);
        return sys.pump(clientResponse, serverResponse);
      });
      return clientRequest;
    };
    return Client;
  })();
  exports.createConnection = function(port, host) {
    var client;
    client = new Client();
    client.port = port;
    client.host = host;
    return client;
  };
  END_OF_FILE = ns.nsWrite("");
  exports.ClientRequest = (function() {
    ClientRequest = function(_arg, _arg2, _arg3, headers, metaVariables) {
      this.path = _arg3;
      this.method = _arg2;
      this.socket = _arg;
      this.writeable = true;
      this._writeQueue = [];
      this._parseEnv(headers, metaVariables);
      this.write(JSON.stringify(this.env));
      return this;
    };
    __extends(ClientRequest, EventEmitter);
    ClientRequest.prototype._parseEnv = function(headers, metaVariables) {
      var _ref2, _result, host, key, name, pathname, port, query, value;
      this.env = {};
      this.env['REQUEST_METHOD'] = this.method;
      _ref2 = url.parse(this.path);
      pathname = _ref2.pathname;
      query = _ref2.query;
      this.env['PATH_INFO'] = pathname;
      this.env['QUERY_STRING'] = query;
      this.env['SCRIPT_NAME'] = "";
      this.env['REMOTE_ADDR'] = "0.0.0.0";
      this.env['SERVER_ADDR'] = "0.0.0.0";
      if (host = headers.host) {
        if ((function() {
          _ref2 = headers.host.split(':');
          name = _ref2.name;
          port = _ref2.port;
          return {
            name: name,
            port: port
          };
        })()) {
          this.env['SERVER_NAME'] = name;
          this.env['SERVER_PORT'] = port;
        }
      }
      _ref2 = headers;
      for (key in _ref2) {
        if (!__hasProp.call(_ref2, key)) continue;
        value = _ref2[key];
        key = key.toUpperCase().replace('-', '_');
        if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
          key = ("HTTP_" + (key));
        }
        this.env[key] = value;
      }
      _result = []; _ref2 = metaVariables;
      for (key in _ref2) {
        if (!__hasProp.call(_ref2, key)) continue;
        value = _ref2[key];
        _result.push(this.env[key] = value);
      }
      return _result;
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
      flushed = (function() {
        if (this._writeQueue) {
          this._writeQueue.push(END_OF_FILE);
          return false;
        } else {
          return this.socket.end(END_OF_FILE);
        }
      }).call(this);
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
  exports.ClientResponse = (function() {
    ClientResponse = function(_arg, _arg2) {
      this.request = _arg2;
      this.socket = _arg;
      this.client = this.socket;
      this.statusCode = null;
      this.headers = null;
      this.finished = false;
      return this;
    };
    __extends(ClientResponse, EventEmitter);
    ClientResponse.prototype._receiveData = function(data) {
      var _ref2, k, v, vs;
      try {
        if (!this.statusCode) {
          return (this.statusCode = JSON.parse(data));
        } else if (!this.headers) {
          this.headers = {};
          _ref2 = JSON.parse(data);
          for (k in _ref2) {
            if (!__hasProp.call(_ref2, k)) continue;
            vs = _ref2[k];
            v = vs.split("\n");
            this.headers[k] = v.length > 0 ? v.join("\r\n" + (k) + ": ") : vs;
          }
          return this.request.emit('response', this);
        } else if (data.length > 0) {
          return this.emit('data', data);
        } else {
          this.finished = true;
          return this.emit('end');
        }
      } catch (error) {
        return this.socket.emit('error', error);
      }
    };
    return ClientResponse;
  })();
}).call(this);
