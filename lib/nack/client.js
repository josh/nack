(function() {
  var BufferedWriteStream, CRLF, Client, ClientRequest, ClientResponse, EventEmitter, Stream, StreamParser, _ref, sys, url;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  };
  sys = require('sys');
  url = require('url');
  _ref = require('net');
  Stream = _ref.Stream;
  _ref = require('events');
  EventEmitter = _ref.EventEmitter;
  _ref = require('nack/buffered');
  BufferedWriteStream = _ref.BufferedWriteStream;
  _ref = require('nack/json');
  StreamParser = _ref.StreamParser;
  CRLF = "\r\n";
  exports.ClientRequest = (function() {
    ClientRequest = function(_arg, _arg2, _arg3, headers) {
      this.path = _arg3;
      this.method = _arg2;
      this.socket = _arg;
      this.bufferedSocket = new BufferedWriteStream(this.socket);
      this.writeable = true;
      this._parseHeaders(headers);
      this.writeObj(this.headers);
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
    ClientRequest.prototype._parseHeaders = function(headers) {
      var _ref2, _result, key, pathname, query, value;
      this.headers = {};
      this.headers["REQUEST_METHOD"] = this.method;
      _ref2 = url.parse(this.path);
      pathname = _ref2.pathname;
      query = _ref2.query;
      this.headers["PATH_INFO"] = pathname;
      this.headers["QUERY_STRING"] = query;
      this.headers["SCRIPT_NAME"] = "";
      _result = []; _ref2 = headers;
      for (key in _ref2) {
        if (!__hasProp.call(_ref2, key)) continue;
        value = _ref2[key];
        _result.push((function() {
          key = key.toUpperCase().replace('-', '_');
          if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
            key = ("HTTP_" + (key));
          }
          return (this.headers[key] = value);
        }).call(this));
      }
      return _result;
    };
    ClientRequest.prototype._initParser = function() {
      var response, streamParser;
      response = new ClientResponse(this.socket);
      streamParser = new StreamParser(this.socket);
      streamParser.on("obj", __bind(function(obj) {
        var _ref2, chunk;
        if (!response.statusCode) {
          response.statusCode = obj;
        } else if (!response.headers) {
          response.headers = obj;
        } else {
          chunk = obj;
        }
        if ((typeof (_ref2 = response.statusCode) !== "undefined" && _ref2 !== null) && (typeof (_ref2 = response.headers) !== "undefined" && _ref2 !== null) && !(typeof chunk !== "undefined" && chunk !== null)) {
          return this.emit('response', response);
        } else if (typeof chunk !== "undefined" && chunk !== null) {
          return response.emit('data', chunk);
        }
      }, this));
      return this.socket.on('end', function() {
        return response.emit('end');
      });
    };
    ClientRequest.prototype.writeObj = function(obj) {
      this.bufferedSocket.write(JSON.stringify(obj));
      return this.bufferedSocket.write(CRLF);
    };
    ClientRequest.prototype.write = function(chunk) {
      return this.writeObj(chunk.toString());
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
    Client.prototype.request = function(method, path, headers) {
      var request;
      this.reconnect();
      request = new ClientRequest(this, method, path, headers);
      return request;
    };
    Client.prototype.proxyRequest = function(serverRequest, serverResponse, callback) {
      var clientRequest;
      clientRequest = this.request(serverRequest.method, serverRequest.url, serverRequest.headers);
      sys.pump(serverRequest, clientRequest);
      return clientRequest.on("response", function(clientResponse) {
        serverResponse.writeHead(clientResponse.statusCode, clientResponse.headers);
        sys.pump(clientResponse, serverResponse, callback);
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
