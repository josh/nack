var process = require('nack/process');

var config = __dirname + "/fixtures/config.ru";

exports.testCreateProcess = function(test) {
  test.expect(4);

  var p = process.createProcess(config);
  test.ok(p.sock);
  test.ok(p.child);

  p.quit(function () {
    test.ok(!p.sock);
    test.ok(!p.child);

    test.done();
  });
};
