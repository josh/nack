(function() {
  var CRLF, Client, jsonParser, net;
  var __bind = function(func, context) {
    return function(){ return func.apply(context, arguments); };
  };
  net = require('net');
  jsonParser = require('nack/json_parser');
  CRLF = "\r\n";
  Client = function() {};
  Client.prototype.connect = function(port, host) {
    return (this.socket = net.createConnection(port, host));
  };
  Client.prototype.proxyRequest = function(req, res) {
    var _a, headers, jsonStream, part, status;
    this.socket.setEncoding("utf8");
    this.socket.addListener("connect", __bind(function() {
      this.socket.write(JSON.stringify(req.headers));
      this.socket.write(CRLF);
      return this.socket.end();
    }, this));
    jsonStream = new jsonParser.Stream(this.socket);
    _a = [null, null, null];
    status = _a[0];
    headers = _a[1];
    part = _a[2];
    jsonStream.addListener("obj", function(obj) {
      if (!(typeof status !== "undefined" && status !== null)) {
        status = obj;
      } else if (!(typeof headers !== "undefined" && headers !== null)) {
        headers = obj;
      } else {
        part = obj;
      }
      if ((typeof status !== "undefined" && status !== null) && (typeof headers !== "undefined" && headers !== null) && !(typeof part !== "undefined" && part !== null)) {
        return res.writeHead(status, headers);
      } else if (typeof part !== "undefined" && part !== null) {
        return res.write(part);
      }
    });
    return this.socket.addListener("end", function(obj) {
      return res.end();
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
