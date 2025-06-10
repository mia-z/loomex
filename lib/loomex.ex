defmodule Loomex do
  def socket do
    DynamicSupervisor.start_child Loomex.SocketSupervisor, {Loomex.Listener, [port: 4044]}
  end
  
  def socket_ssl do
    DynamicSupervisor.start_child Loomex.SocketSupervisor, {Loomex.Listener, [port: 4044, mode: :ssl]}
  end
  
  def socket(opts) do
    DynamicSupervisor.start_child Loomex.SocketSupervisor, {Loomex.Listener, opts}
  end
  
  @spec server(opts :: [mode: :tcp | :ssl, port: 1001..65535]) :: DynamicSupervisor.on_start_child()
  def server(opts \\ [mode: :tcp, port: 4044]) do
    DynamicSupervisor.start_child Loomex.SocketSupervisor, {Loomex.Listener, opts}
  end
end