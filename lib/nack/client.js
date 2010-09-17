(function() {
  var BufferedStream, CRLF, Client, ClientRequest, ClientResponse, EventEmitter, Stream, StreamParser, _a, _b, _c, _d, sys, url;
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
  _a = require('net');
  Stream = _a.Stream;
  _b = require('events');
  EventEmitter = _b.EventEmitter;
  _c = require('nack/buffered_stream');
  BufferedStream = _c.BufferedStream;
  _d = require('nack/json');
  StreamParser = _d.StreamParser;
  CRLF = "\r\n";
  exports.ClientRequest = (function() {
    ClientRequest = function(_e, _f, _g, headers) {
      this.path = _g;
      this.method = _f;
      this.socket = _e;
      ClientRequest.__super__.constructor.call(this, this.socket);
      this._parseHeaders(headers);
      this.write(this.headers);
      this.socket.on('connect', __bind(function() {
        return this.flush();
      }, this));
      this._initParser();
      return this;
    };
    __extends(ClientRequest, BufferedStream);
    ClientRequest.prototype._parseHeaders = function(headers) {
      var _e, _f, _g, key, pathname, query, value;
      this.headers = {};
      this.headers["REQUEST_METHOD"] = this.method;
      _e = url.parse(this.path);
      pathname = _e.pathname;
      query = _e.query;
      this.headers["PATH_INFO"] = pathname;
      this.headers["QUERY_STRING"] = query;
      this.headers["SCRIPT_NAME"] = "";
      _f = []; _g = headers;
      for (key in _g) {
        if (!__hasProp.call(_g, key)) continue;
        value = _g[key];
        _f.push((function() {
          key = key.toUpperCase().replace('-', '_');
          if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
            key = ("HTTP_" + (key));
          }
          return (this.headers[key] = value);
        }).call(this));
      }
      return _f;
    };
    ClientRequest.prototype._initParser = function() {
      var response, streamParser;
      response = new ClientResponse(this.socket);
      streamParser = new StreamParser(this.socket);
      streamParser.on("obj", __bind(function(obj) {
        var _e, _f, chunk;
        if (!response.statusCode) {
          response.statusCode = obj;
        } else if (!response.headers) {
          response.headers = obj;
        } else {
          chunk = obj;
        }
        if ((typeof (_e = response.statusCode) !== "undefined" && _e !== null) && (typeof (_f = response.headers) !== "undefined" && _f !== null) && !(typeof chunk !== "undefined" && chunk !== null)) {
          return this.emit('response', response);
        } else if (typeof chunk !== "undefined" && chunk !== null) {
          return response.emit('data', chunk);
        }
      }, this));
      return this.socket.on('end', function() {
        return response.emit('end');
      });
    };
    ClientRequest.prototype.write = function(chunk) {
      ClientRequest.__super__.write.call(this, new Buffer(JSON.stringify(chunk)));
      return ClientRequest.__super__.write.call(this, new Buffer(CRLF));
    };
    return ClientRequest;
  })();
  exports.ClientResponse = (function() {
    ClientResponse = function(_e) {
      this.socket = _e;
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
    Client.prototype.proxyRequest = function(serverRequest, serverResponse) {
      var clientRequest;
      clientRequest = this.request(serverRequest.method, serverRequest.url, serverRequest.headers);
      serverRequest.on("data", __bind(function(chunk) {
        return clientRequest.write(chunk);
      }, this));
      serverRequest.on("end", __bind(function(chunk) {
        return clientRequest.end();
      }, this));
      return clientRequest.on("response", function(clientResponse) {
        serverResponse.writeHead(clientResponse.statusCode, clientResponse.headers);
        clientResponse.on("data", function(chunk) {
          return serverResponse.write(chunk);
        });
        return clientResponse.on("end", function() {
          return serverResponse.end();
        });
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
})();
