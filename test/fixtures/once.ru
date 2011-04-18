$count = 0

run lambda { |env|
  $count += 1
  raise "count: #{$count}" if $count > 1
  [200, {"Content-Type" => "text/plain"}, [env["rack.run_once"].to_s]]
}
