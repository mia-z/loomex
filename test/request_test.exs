defmodule RequestTest do
  use ExUnit.Case

  @url_with_one_query %Request{query_string: "param1key=param1value"}
  @url_with_two_queries %Request{query_string: "param1key=param1value&param2key=param2value"}

  test "gets query pair from url with one query " do
    test_value = Request.get_query_map @url_with_one_query
    assert test_value == %{ "param1key" => "param1value" }
  end
  
  test "gets query pair from url with two queries " do
    test_value = Request.get_query_map @url_with_two_queries
    assert test_value == %{ "param1key" => "param1value", "param2key" => "param2value" }
  end
end
