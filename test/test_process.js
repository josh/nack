var process = require('nack/process');

var config = __dirname + "/fixtures/hello.ru";

exports.testCreateProcess = function(test) {
  test.expect(5);

  var p = process.createProcess(config);
  test.ok(p.sock);
  test.ok(p.child);

  p.on('ready', function() {
    test.ok(true);

    p.quit();
    p.on('exit', function () {
      test.ok(!p.sock);
      test.ok(!p.child);

      test.done();
    });
  });
};
