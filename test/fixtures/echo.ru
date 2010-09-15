run lambda { |env|
  body = env["rack.input"].read
  [200, {"Content-Type" => "text/plain"}, [body]]
}
