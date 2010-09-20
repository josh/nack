run lambda { |env|
  body = env["rack.input"].read
  [200, {"Content-Type" => "text/plain", "Set-Cookie" => "foo=1\nbar=2"}, [body]]
}
