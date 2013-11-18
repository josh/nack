require 'rake/testtask'

task :default => :test

ENV['PATH'] = "#{File.expand_path("../bin", __FILE__)}:#{ENV['PATH']}"
ENV['RUBYLIB'] = "#{File.expand_path("../lib", __FILE__)}:#{ENV['RUBYLIB']}"

Rake::TestTask.new do |t|
  t.warning = true
end
