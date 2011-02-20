require 'rake/testtask'

task :default => :test

ENV['PATH'] = "#{File.expand_path("../bin", __FILE__)}:#{ENV['PATH']}"

Rake::TestTask.new do |t|
  t.warning = true
end

task :pages => "pages:build"

namespace :pages do
  task :publish do
    rm_rf "pages"

    url = `git remote show origin`.grep(/Push.*URL/).first[/git@.*/]
    sh "git clone -q -b gh-pages #{url} pages"

    sh "rm -rf pages/*"

    Rake::Task['pages:build'].invoke

    cd "pages" do
      sh "git add ."
      sh "git commit -m 'rebuild manual'"
      sh "git push #{url} gh-pages"
    end

    rm_rf "pages/"
  end
end
