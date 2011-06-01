run lambda { |env|
  [200, {
     'Content-Type' => 'text/plain'
   }, ['foo', 'bar', "\nbaz"]]
}
