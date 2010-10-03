(function() {
  var BufferedWriteStream, Client, ClientRequest, ClientResponse, EventEmitter, Stream, _ref, ns, sys, url;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  }, __slice = Array.prototype.slice;
  sys = require('sys');
  url = require('url');
  ns = require('nack/ns');
  _ref = require('net');
  Stream = _ref.Stream;
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  _ref = require('nack/buffered');
  BufferedWriteStream = _ref.BufferedWriteStream;
  exports.ClientRequest = (function() {
    ClientRequest = function(_arg, _arg2, _arg3, headers, metaVariables) {
      this.path = _arg3;
      this.method = _arg2;
      this.socket = _arg;
      this.bufferedSocket = new BufferedWriteStream(this.socket);
      this.writeable = true;
      this._parseEnv(headers, metaVariables);
      this.write(JSON.stringify(this.env));
      this.socket.on('connect', __bind(function() {
        return this.bufferedSocket.flush();
      }, this));
      this.bufferedSocket.on('drain', __bind(function() {
        return this.emit('drain');
      }, this));
      this.bufferedSocket.on('close', __bind(function() {
        return this.emit('close');
      }, this));
      this._initParser();
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
    ClientRequest.prototype._initParser = function() {
      var nsStream, response;
      response = new ClientResponse(this.socket);
      nsStream = new ns.Stream(this.socket);
      nsStream.on('data', __bind(function(data) {
        var _i, _len, _ref2, _ref3, chunk, k, v, vs;
        if (!response.statusCode) {
          response.statusCode = JSON.parse(data);
        } else if (!response.headers) {
          response.headers = [];
          _ref2 = JSON.parse(data);
          for (k in _ref2) {
            if (!__hasProp.call(_ref2, k)) continue;
            vs = _ref2[k];
            _ref3 = vs.split("\n");
            for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
              v = _ref3[_i];
              response.headers.push([k, v]);
            }
          }
        } else {
          chunk = data;
        }
        if ((typeof (_ref2 = response.statusCode) !== "undefined" && _ref2 !== null) && (typeof (_ref2 = response.headers) !== "undefined" && _ref2 !== null) && !(typeof chunk !== "undefined" && chunk !== null)) {
          return this.emit('response', response);
        } else if (typeof chunk !== "undefined" && chunk !== null) {
          return response.emit('data', chunk);
        }
      }, this));
      nsStream.on('error', __bind(function(exception) {
        return this.stream.emit('error', exception);
      }, this));
      return this.socket.on('end', function() {
        return response.emit('end');
      });
    };
    ClientRequest.prototype.write = function(chunk) {
      return this.bufferedSocket.write(ns.nsWrite(chunk.toString()));
    };
    ClientRequest.prototype.end = function() {
      return this.bufferedSocket.end();
    };
    return ClientRequest;
  })();
  exports.ClientResponse = (function() {
    ClientResponse = function(_arg) {
      this.socket = _arg;
      this.client = this.socket;
      this.statusCode = null;
      this.headers = null;
      return this;
    };
    __extends(ClientResponse, EventEmitter);
    return ClientResponse;
  })();
  exports.Client = (function() {
    Client = function() {
      return Stream.apply(this, arguments);
    };
    __extends(Client, Stream);
    Client.prototype.reconnect = function() {
      return this.readyState === 'closed' ? this.connect(this.port, this.host) : null;
    };
    Client.prototype.request = function() {
      var _ctor, _ref2, _result, args, request;
      args = __slice.call(arguments, 0);
      this.reconnect();
      request = (function() {
        var ctor = function(){};
        __extends(ctor, _ctor = ClientRequest);
        return typeof (_result = _ctor.apply(_ref2 = new ctor, [this].concat(args))) === "object" ? _result : _ref2;
      }).call(this);
      return request;
    };
    Client.prototype.proxyRequest = function(serverRequest, serverResponse, callback) {
      var clientRequest, metaVariables;
      metaVariables = {
        "REMOTE_ADDR": serverRequest.connection.remoteAddress,
        "REMOTE_PORT": serverRequest.connection.remotePort
      };
      clientRequest = this.request(serverRequest.method, serverRequest.url, serverRequest.headers, metaVariables);
      sys.pump(serverRequest, clientRequest);
      this.on("error", function(err) {
        return callback(err);
      });
      return clientRequest.on("response", function(clientResponse) {
        serverResponse.writeHead(clientResponse.statusCode, clientResponse.headers);
        sys.pump(clientResponse, serverResponse);
        return (typeof callback !== "undefined" && callback !== null) ? clientResponse.on("end", callback) : null;
      });
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
}).call(this);
