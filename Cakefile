fs = require 'fs'

{spawn, exec} = require 'child_process'
{basename, join} = require 'path'

task 'build', "Build CoffeeScript source files", ->
  coffee = spawn 'coffee', ['-cw', '-o', 'lib', 'src']
  coffee.stdout.on 'data', (data) -> process.stderr.write data.toString()

task 'test', "Run test suite", ->
  exec 'which ruby', (err) ->
    throw "ruby not found" if err

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
  {series, parallel} = require 'async'
  sh = (command) -> (k) -> exec command, k

  buildMan = (callback) ->
    series [
      (sh "cp README.md doc/index.md")
      (sh "ronn -stoc -5 doc/*.md")
      (sh "mv doc/*.html pages/")
      (sh "rm doc/index.md")
    ], callback

  buildAnnotations = (callback) ->
    series [
      (sh "docco src/**/*.coffee")
      (sh "mv docs/* pages/annotations")
      (sh "rm -rf docs/")
    ], callback

  build = (callback) ->
    parallel [buildMan, buildAnnotations], callback

  checkoutBranch = (callback) ->
    series [
      (sh "rm -rf pages/")
      (sh "git clone -q -b gh-pages git@github.com:josh/nack.git pages")
      (sh "rm -rf pages/*")
    ], callback

  publish = (callback) ->
    series [
      (sh "cd pages/ && git commit -am 'rebuild manual' || true")
      (sh "cd pages/ && git push git@github.com:josh/nack.git gh-pages")
      (sh "rm -rf pages/")
    ], callback

  series [
    checkoutBranch
    (sh "mkdir -p pages/annotations")
    build
    publish
  ], (err) -> throw err if err
