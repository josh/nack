run lambda { |env|
  [200, {
     "Content-Type" => "text/x-script.ruby",
     "Content-Length" => "0",
     "X-Sendfile" => File.expand_path(__FILE__)
   }, []]
}
