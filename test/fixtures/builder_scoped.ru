class Object
  def run *args
    raise "Nack should never call this method."
  end
end

run lambda { |env| [200, {"Content-Type" => "text/plain"}, ["Properly scoped"]] }
