{realpathSync} = require 'fs'
dirname = realpathSync __dirname

require.paths.unshift dirname + "/lib"
process.env['PATH'] = dirname + "/bin:" + process.env['PATH']
process.env['RUBYLIB'] = dirname + "/lib:" + process.env['RUBYLIB']

{print} = require 'sys'
{spawn} = require 'child_process'

task 'build', 'Build CoffeeScript source files', ->
  coffee = spawn 'coffee', ['-cw', '-o', 'lib', 'src']
  coffee.stdout.on 'data', (data) -> print data.toString()

task 'test', 'Run test suite', ->
  process.chdir __dirname
  {reporters} = require 'nodeunit'
  reporters.default.run ['test']
