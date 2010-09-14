require 'rake/testtask'

task :default => :test

task :default => [:test_ruby, :test_node]

Rake::TestTask.new(:test_ruby) do |t|
  t.warning = true
end

task :test_node do
  path = "/tmp/nack_test.js"
  write_node_test_script path
  system "node #{path}"
end

def write_node_test_script(path)
  return if File.exist?(path)

  pwd = File.expand_path('..', __FILE__)
  lib = File.expand_path('../lib', __FILE__)

  script = <<-EOS
    require.paths.push("#{lib}");
    var testrunner = require('nodeunit').testrunner;
    process.chdir("#{pwd}");
    testrunner.run(['test']);
  EOS

  File.open(path, "w") { |f| f << script }
end
