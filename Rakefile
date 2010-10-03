require 'rake/testtask'

task :default => :test

ENV['PATH'] = "#{File.expand_path("../bin", __FILE__)}:#{ENV['PATH']}"

Rake::TestTask.new do |t|
  t.warning = true
end

Version = "0.1.1"

file "nack-#{Version}.gem" do
  sh "gem build nack.gemspec"
end

task :release => ["nack-#{Version}.gem"] do
  sh "gem push nack-#{Version}.gem"
  sh "npm publish"

  sh "rm nack-*.gem"
end
