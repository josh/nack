Gem::Specification.new do |s|
  s.name     = 'nack'
  s.version  = '0.0.0'
  s.date     = '2010-09-19'
  s.summary  = 'Node Rack server'
  s.description = <<-EOS
    Node powered Rack server
  EOS

  s.files = [
    'lib/nack.rb',
    'lib/nack/builder',
    'lib/nack/client'
    'lib/nack/error',
    'lib/nack/netstring',
    'lib/nack/server'
  ]
  s.executables = ['nackup']
  s.extra_rdoc_files = ['README.md', 'LICENSE']

  s.author   = 'Joshua Peek'
  s.email    = 'josh@joshpeek.com'
  s.homepage = 'http://github.com/josh/nack'
  s.rubyforge_project = 'nack'
end
