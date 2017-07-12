run lambda { |env|
  begin
    raise "b00m"
  rescue => e
    # If there is a `cause`, raise it instead of the "b00m" exception that we are expecting.
    raise e.cause || e
  end
}
