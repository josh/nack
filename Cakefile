{print} = require 'sys'
{spawn} = require 'child_process'

task 'build', 'Build CoffeeScript source files', ->
  coffee = spawn 'coffee', ['-cw', '-o', 'lib', 'src']
  coffee.stdout.on 'data', (data) -> print data.toString()

task 'test', 'Run test suite', ->
  process.chdir __dirname
  {reporters} = require 'nodeunit'
  reporters.default.run ['test']
