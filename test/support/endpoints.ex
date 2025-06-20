defmodule Support.Endpoints do
  use EndpointBuilder
  require Logger
  endpoint "/" do
    ok()
  end
  
  endpoint "/hello" do
    ok "world"
  end
  
  endpoint "/users/:user" do
    user = route[:user]
    ok("Welcome, user #{user}")
  end
  
  get "/get" do
    ok()
  end
  
  post "post_with_body" do
    Logger.info "#{inspect json["field_one"]}"
    ok()
  end
  
  get "/json_result" do
    json_result(%{value_one: "hello!", name: "Ryan", age: 31})
  end
  
  get "/text_result" do
    text_result("Just some text")
  end
end