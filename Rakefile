require 'rake/testtask'

task :default => :test

ENV['PATH'] = "#{File.expand_path("../bin", __FILE__)}:#{ENV['PATH']}"

Rake::TestTask.new do |t|
  t.warning = true
end

require 'rake/clean'

CLOBBER.include('man/*')

desc 'Build the manual'
task :man => ([:clobber] + Dir["doc/*"].map { |doc|
  man = File.join("man", File.basename(doc, '.md'))
  file man do
    sh "ronn --pipe --roff #{doc} > #{man}"
  end
  man
})

require 'rake/gempackagetask'
spec = eval(File.read("nack.gemspec"))
gem_task = Rake::GemPackageTask.new(spec) do
end

task :release => :gem do
  sh "gem push pkg/#{gem_task.gem_file}"
  sh "npm publish"

  sh "rm -r pkg/"
end
