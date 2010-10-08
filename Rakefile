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

task :pages => "pages:build"

namespace :pages do
  task :build => ["pages:man", "pages:docco"]

  task :man do
    mkdir_p "pages"

    sh "ronn -stoc -5 doc/*"
    sh "mv doc/*.html pages/"
  end

  task :docco do
    mkdir_p "pages"

    sh "docco src/**/*.coffee"
    sh "mv docs/* pages/"

    rm_r "docs/"
  end

  task :publish do
    rm_rf "pages"

    url = `git remote show origin`.grep(/Push.*URL/).first[/git@.*/]
    sh "git clone -q -b gh-pages #{url} pages"

    sh "rm pages/*"

    Rake::Task['pages:build'].invoke

    cd "pages" do
      sh "git add ."
      sh "git commit -m 'rebuild manual'"
      sh "git push #{url} gh-pages"
    end

    rm_rf "pages/"
  end
end

require 'rake/gempackagetask'
spec = eval(File.read("nack.gemspec"))
gem_task = Rake::GemPackageTask.new(spec) do
end

task :release => :gem do
  sh "gem push pkg/#{gem_task.gem_file}"
  sh "npm publish"

  sh "rm -r pkg/"
end
