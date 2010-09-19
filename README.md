nack
====

Node powered Rack server.

Installation
------------

nack is distributed as 2 packages.

You can grab the javascript client from npm.

    npm install nack

The ruby server is available on RubyGems.

    gem install nack

Example
-------

    var http = require('http');
    var nack = require('nack/process');

    var app = nack.createProcess("/path/to/app/config.ru");

    http.createServer(function (req, res) {
      app.proxyRequest(req, res);
    }).listen(8124, "127.0.0.1");
