defmodule Support.Endpoints do
  use EndpointBuilder
  
  endpoint "/" do
    ok()
  end
  
  endpoint "/hello" do
    ok()
  end
end