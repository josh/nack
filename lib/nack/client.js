var net        = require('net');
var jsonParser = require('nack/json_parser');

var crlf = "\r\n";

exports.request = function (path, req, res) {
  var client = net.createConnection(path);
  client.setEncoding("utf8");

  client.addListener("connect", function () {
    client.write(JSON.stringify(req.headers));
    client.write(crlf);

    client.end();

    // req.addListener("data", function (chunk) {
    //   client.write(JSON.stringify(chunk));
    //   client.write(crlf);
    // });

    // req.addListener("end", function (chunk) {
    //   client.end();
    // });
  });

  var jsonStream = new jsonParser.Stream(client);

  var status, headers, part;
  jsonStream.addListener("obj", function (obj) {
    if (status == null)
      status = obj
    else if (headers == null)
      headers = obj
    else
      part = obj

    if (status && headers && part == null)
      res.writeHead(status, headers);
    else if (part)
      res.write(part);
  });

  client.addListener("end", function (obj) {
    res.end();
  });
}
