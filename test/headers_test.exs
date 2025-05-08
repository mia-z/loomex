defmodule HeadersTest do
  use ExUnit.Case
  
  @header_string "Content-Type: application/json\r\nAccept: application/json\r\nDate: Mon, 18 Jul 2016 16:06:00 GMT\r\nKeep-Alive: timeout=5, max=997\r\n"
  @header_list ["Content-Type: application/json", "Accept: application/json", "Date: Mon, 18 Jul 2016 16:06:00 GMT", "Keep-Alive: timeout=5, max=997"]
  
  @header_map %{
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Date" => "Mon, 18 Jul 2016 16:06:00 GMT",
    "Keep-Alive" => "timeout=5, max=997"
  }
  
  test "creates headers map from string" do
    headers = Headers.new @header_string
    assert headers == @header_map
  end
  
  test "creates headers map from list" do
    headers = Headers.new @header_list
    assert headers == @header_map
  end
end