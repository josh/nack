{createProcess} = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

exports.testCreateProcess = (test) ->
  test.expect 9

  process = createProcess config
  process.on 'spawn', () ->
    test.ok true

  process.spawn()

  test.ok process.sockPath
  test.ok process.child

  test.ok process.stdout
  test.ok process.stderr

  process.stdout.on 'data', () ->
    test.ok true

  process.on 'ready', () ->
    test.ok true

    process.quit()
    process.on 'exit', () ->
      test.ok !process.sockPath
      test.ok !process.child

      test.done()
