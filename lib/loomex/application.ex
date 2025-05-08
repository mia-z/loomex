defmodule Loomex.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      Router.RoutingTable,
      {DynamicSupervisor, name: Loomex.SocketSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Loomex.PipelineSupervisor, strategy: :one_for_one}
    ]
    opts = [strategy: :one_for_one, name: Loomex.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  def stop do
    Supervisor.stop Loomex.Supervisor
  end
end