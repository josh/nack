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

Dependencies
------------

* node >= 0.2.3
* rack
* json

Example
-------

Simple proxy

    var http = require('http');
    var nack = require('nack');

    var app = nack.createProcess("/path/to/app/config.ru");

    http.createServer(function (req, res) {
      app.proxyRequest(req, res);
    }).listen(8124, "127.0.0.1");

You can spawn up a pool of workers with:

    var nack = require('nack');
    nack.createPool("/path/to/app/config.ru", { size: 3 });

Workers can idle out after a period of inactivity:

    // Timeout after 15m
    nack.createPool("/path/to/app/config.ru", { idle: 15 * 60 * 1000 });

"Roadmap"
--------

* Robustification
* JSGI / Connect adapters
* Binary protocol for IPC

Caveats
-------

nack was design to be used as a local development proxy. You probably don't wanna try running a production app on it. I'm sure its slow too so don't send me any benchmarks.
