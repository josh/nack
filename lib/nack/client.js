(function() {
  var BufferedStream, CRLF, Client, ClientRequest, ClientResponse, EventEmitter, Stream, _a, _b, _c, jsonParser, url;
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
  url = require('url');
  jsonParser = require('nack/json_parser');
  _a = require('net');
  Stream = _a.Stream;
  _b = require('events');
  EventEmitter = _b.EventEmitter;
  _c = require('nack/buffered_stream');
  BufferedStream = _c.BufferedStream;
  CRLF = "\r\n";
  exports.ClientRequest = (function() {
    ClientRequest = function(_d, _e, _f, headers) {
      var _g, _h, jsonStream, key, pathname, query, response, value;
      this.path = _f;
      this.method = _e;
      this.socket = _d;
      ClientRequest.__super__.constructor.call(this, this.socket);
      this.headers = {};
      this.headers["REQUEST_METHOD"] = this.method;
      _g = url.parse(this.path);
      pathname = _g.pathname;
      query = _g.query;
      this.headers["PATH_INFO"] = pathname;
      this.headers["QUERY_STRING"] = query;
      this.headers["SCRIPT_NAME"] = "";
      _h = headers;
      for (key in _h) {
        if (!__hasProp.call(_h, key)) continue;
        value = _h[key];
        key = key.toUpperCase().replace('-', '_');
        if (!(key === 'CONTENT_TYPE' || key === 'CONTENT_LENGTH')) {
          key = ("HTTP_" + (key));
        }
        this.headers[key] = value;
      }
      this.write(this.headers);
      this.socket.on('connect', __bind(function() {
        return this.flush();
      }, this));
      response = new ClientResponse(this.socket);
      jsonStream = new jsonParser.Stream(this.socket);
      jsonStream.on("obj", __bind(function(obj) {
        var _i, _j, chunk;
        if (!response.statusCode) {
          response.statusCode = obj;
        } else if (!response.headers) {
          response.headers = obj;
        } else {
          chunk = obj;
        }
        if ((typeof (_i = response.statusCode) !== "undefined" && _i !== null) && (typeof (_j = response.headers) !== "undefined" && _j !== null) && !(typeof chunk !== "undefined" && chunk !== null)) {
          return this.emit('response', response);
        } else if (typeof chunk !== "undefined" && chunk !== null) {
          return response.emit('data', chunk);
        }
      }, this));
      this.socket.on('end', function() {
        return response.emit('end');
      });
      return this;
    };
    __extends(ClientRequest, BufferedStream);
    ClientRequest.prototype.write = function(chunk) {
      ClientRequest.__super__.write.call(this, new Buffer(JSON.stringify(chunk)));
      return ClientRequest.__super__.write.call(this, new Buffer(CRLF));
    };
    return ClientRequest;
  })();
  exports.ClientResponse = (function() {
    ClientResponse = function(_d) {
      this.socket = _d;
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
    Client.prototype.proxyRequest = function(req, res) {
      var clientRequest;
      clientRequest = this.request(req.method, req.url, req.headers);
      req.on("data", __bind(function(chunk) {
        return clientRequest.write(chunk);
      }, this));
      req.on("end", __bind(function(chunk) {
        return clientRequest.end();
      }, this));
      return clientRequest.on("response", function(clientResponse) {
        res.writeHead(clientResponse.statusCode, clientResponse.headers);
        clientResponse.on("data", function(chunk) {
          return res.write(chunk);
        });
        return clientResponse.on("end", function() {
          return res.end();
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
