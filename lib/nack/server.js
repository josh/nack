var client = require('nack/client');
var spawn  = require('child_process').spawn;

var nackup = __dirname + "/../../bin/nackup"

var Server = function (config) {
  // TODO: Create a new sock for each server
  this.sock = __dirname + "/../../test/nack.sock";

  spawn(nackup, ['--file', this.sock, config]);

  return this;
}
exports.Server = Server;

Server.prototype.request = function (req, res) {
  client.request(this.sock, req, res);
}

exports.createServer = function (config) {
  return new Server(config);
}
