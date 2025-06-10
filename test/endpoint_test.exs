defmodule EndpointTest do  
  use ExUnit.Case, async: false

  setup_all do
    with {:ok, tcp_pid} <- Loomex.socket(port: 4044, mode: :tcp),
      {:ok, ssl_pid} <- Loomex.socket(port: 4045, mode: :ssl) do
        on_exit(fn -> 
          DynamicSupervisor.terminate_child Loomex.SocketSupervisor, tcp_pid
          DynamicSupervisor.terminate_child Loomex.SocketSupervisor, ssl_pid
        end)
      end
    :ok
  end
  
  test "Endpoint returns 200 OK" do
    res = Req.get!("http://localhost:4044/")
    assert res.status == 200
  end
  
  test "Endpoint with path returns 200 OK" do
    res = Req.get!("http://localhost:4044/hello")
    assert res.status == 200
  end
end