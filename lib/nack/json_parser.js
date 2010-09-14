var events = require('events');

var crlf = "\r\n";

exports.Stream = function (client) {
  var stream = new events.EventEmitter();

  var buffer = "";
  client.addListener("data", function (chunk) {
    buffer += chunk;

    var index;
    while ((index = buffer.indexOf(crlf)) !== -1) {
      json   = buffer.slice(0, index);
      buffer = buffer.slice(index + crlf.length);

      stream.emit('obj', JSON.parse(json));
    }
  });

  return stream;
}
