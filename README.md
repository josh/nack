nack -- Node powered Rack server
================================

## DESCRIPTION

nack is a [Rack](http://github.com/rack/rack) server built on top of the [Node.js](http://nodejs.org/) HTTP server. Node does all the hard work of accepting and parsing HTTP requests and nack simply passes it along to a Ruby worker process as a serialized object. You can read more about how the IPC protocol works. Besides running as a standalone Rack server, you can use the JS API to run multiple apps from the same Node process.

## EXAMPLES

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

Theres a more friendly server API that returns a [Connect](http://senchalabs.github.com/connect/) application.

    var connect = require('connect');
    var nack    = require('nack');

    connect.createServer(
      connect.logger(),
      connect.vhost('foo.test',
        nack.createServer("/u/apps/foo/config.ru")
      ),
      connect.vhost('bar.test',
        nack.createServer("/u/apps/bar/config.ru")
      )
    ).listen(3000);

## INSTALL

nack is distributed as 2 packages.

You can grab the javascript client from npm.

    npm install nack

The ruby server is available on RubyGems.

    gem install nack

### DEPENDENCIES

* node >= 0.2.3
* node-netstring
* rack
* json

## CAVEATS

nack was design to be used as a local development proxy. You probably don't wanna try running a production app on it. I'm sure its slow too so don't send me any benchmarks.

## License

Copyright (c) 2010 Joshua Peek.

Released under the MIT license. See `LICENSE` for details.

## SEE ALSO

nack(1), nack-protocol(7), <http://josh.github.com/nack/annotations>
