fs = require 'fs'

{spawn, exec} = require 'child_process'
{basename, join} = require 'path'

task 'build', "Build CoffeeScript source files", ->
  coffee = spawn 'coffee', ['-cw', '-o', 'lib', 'src']
  coffee.stdout.on 'data', (data) -> process.stderr.write data.toString()

task 'test', "Run test suite", ->
  process.chdir __dirname
  {reporters} = require 'nodeunit'
  reporters.default.run ['test']

task 'man', "Build manuals", ->
  fs.readdir "doc/", (err, files) ->
    for file in files when /\.md/.test file
      source = join "doc", file
      target = join "man", basename source, ".md"
      exec "ronn --pipe --roff #{source} > #{target}", (err) ->
        throw err if err

task 'pages', "Build pages", ->
  exec "mkdir -p pages/annotations", ->
    exec "cp README.md doc/index.md", ->
      exec "ronn -stoc -5 doc/*.md", (err) ->
        throw err if err
        exec "mv doc/*.html pages/", ->
          fs.unlink "doc/index.md", ->

    exec "docco src/**/*.coffee", (err) ->
      throw err if err
      exec "mv docs/* pages/annotations", (err) ->
        exec "rm -r docs/", ->
