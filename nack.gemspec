Gem::Specification.new do |s|
  s.name     = 'nack'
  s.version  = '0.3.3'
  s.date     = '2011-01-03'
  s.summary  = 'Node Rack server'
  s.description = <<-EOS
    Node powered Rack server
  EOS

  s.files = [
    'lib/nack.rb',
    'lib/nack/builder.rb',
    'lib/nack/client.rb',
    'lib/nack/error.rb',
    'lib/nack/netstring.rb',
    'lib/nack/server.rb'
  ]
  s.executables = ['nack_worker']
  s.extra_rdoc_files = ['README.md', 'LICENSE']

  s.author   = 'Joshua Peek'
  s.email    = 'josh@joshpeek.com'
  s.homepage = 'http://github.com/josh/nack'
  s.rubyforge_project = 'nack'
end
