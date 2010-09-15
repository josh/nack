(function() {
  var CRLF, Client, ClientRequest, ClientResponse, EventEmitter, _a, jsonParser, net, url;
  var __hasProp = Object.prototype.hasOwnProperty, __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  }, __extends = function(child, parent) {
    var ctor = function(){};
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
    child.prototype.constructor = child;
    if (typeof parent.extended === "function") parent.extended(child);
    child.__super__ = parent.prototype;
  };
  net = require('net');
  url = require('url');
  jsonParser = require('nack/json_parser');
  _a = require('events');
  EventEmitter = _a.EventEmitter;
  CRLF = "\r\n";
  ClientRequest = function(_b, method, path, headers) {
    this.socket = _b;
    this.connected = false;
    this.ended = false;
    this.headers = this.parseRequest(method, path, headers);
    this.buffer = [];
    this.buffer.push(new Buffer(JSON.stringify(this.headers)));
    this.buffer.push(new Buffer(CRLF));
    this.connect();
    return this;
  };
  __extends(ClientRequest, EventEmitter);
  ClientRequest.prototype.parseRequest = function(method, path, request_headers) {
    var _b, _c, headers, key, pathname, query, value;
    headers = {};
    headers["REQUEST_METHOD"] = method;
    _b = url.parse(path);
    pathname = _b.pathname;
    query = _b.query;
    headers["PATH_INFO"] = pathname;
    headers["QUERY_STRING"] = query;
    headers["SCRIPT_NAME"] = "";
    _c = request_headers;
    for (key in _c) {
      if (!__hasProp.call(_c, key)) continue;
      value = _c[key];
      key = key.toUpperCase().replace('-', '_');
      if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
        key = ("HTTP_" + (key));
      }
      headers[key] = value;
    }
    return headers;
  };
  ClientRequest.prototype.connect = function() {
    var response, stream;
    this.socket.setEncoding("utf8");
    this.socket.addListener("connect", __bind(function() {
      this.connected = true;
      this.flush();
      if (this.ended) {
        return this.socket.end();
      }
    }, this));
    response = new ClientResponse(this.socket);
    stream = new jsonParser.Stream(this.socket);
    stream.addListener("obj", __bind(function(obj) {
      var _b, _c, chunk;
      if (!response.statusCode) {
        response.statusCode = obj;
      } else if (!response.headers) {
        response.headers = obj;
      } else {
        chunk = obj;
      }
      if ((typeof (_b = response.statusCode) !== "undefined" && _b !== null) && (typeof (_c = response.headers) !== "undefined" && _c !== null) && !(typeof chunk !== "undefined" && chunk !== null)) {
        return this.emit("response", response);
      } else if (typeof chunk !== "undefined" && chunk !== null) {
        return response.emit("data", chunk);
      }
    }, this));
    return this.socket.addListener("end", function() {
      return response.emit("end");
    });
  };
  ClientRequest.prototype.flush = function() {
    var _b;
    if (this.connected) {
      _b = [];
      while (this.buffer.length > 0) {
        _b.push(this.socket.write(this.buffer.shift()));
      }
      return _b;
    }
  };
  ClientRequest.prototype.write = function(chunk) {
    this.buffer.push(new Buffer(JSON.stringify(chunk)));
    this.buffer.push(new Buffer(CRLF));
    return this.flush();
  };
  ClientRequest.prototype.end = function() {
    this.ended = true;
    if (this.connected) {
      this.flush();
      return this.socket.end();
    }
  };
  exports.ClientRequest = ClientRequest;
  ClientResponse = function(_b) {
    this.socket = _b;
    this.statusCode = null;
    this.headers = null;
    return this;
  };
  __extends(ClientResponse, EventEmitter);
  exports.ClientResponse = ClientResponse;
  Client = function() {};
  Client.prototype.connect = function(port, host) {
    return (this.socket = net.createConnection(port, host));
  };
  Client.prototype.request = function(method, path, headers) {
    var request;
    request = new ClientRequest(this.socket, method, path, headers);
    request.connect;
    return request;
  };
  Client.prototype.proxyRequest = function(req, res) {
    var clientRequest;
    clientRequest = this.request(req.method, req.url, req.headers);
    req.addListener("data", __bind(function(chunk) {
      return clientRequest.write(chunk);
    }, this));
    req.addListener("end", __bind(function(chunk) {
      return clientRequest.end();
    }, this));
    return clientRequest.on("response", function(clientResponse) {
      res.writeHead(clientResponse.statusCode, clientResponse.headers);
      clientResponse.on("data", function(chunk) {
        return res.write(chunk);
      });
      return clientResponse.addListener("end", function() {
        return res.end();
      });
    });
  };
  exports.Client = Client;
  exports.createConnection = function(port, host) {
    var client;
    client = new Client();
    client.connect(port, host);
    return client;
  };
})();
