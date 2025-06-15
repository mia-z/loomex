defmodule Loomex.Application do
  require Logger
  use Application
  
  def start(_type, _args) do
    children = [
      Router.RoutingTable,
      # {PartitionSupervisor, child_spec: DynamicSupervisor, name: Loomex.PipelineSupervisor},
      {DynamicSupervisor, name: Loomex.PipelineSupervisor, strategy: :one_for_one},
      {PartitionSupervisor, child_spec: Task.Supervisor, name: Loomex.PipelineTaskSupervisor},
      {PartitionSupervisor, child_spec: DynamicSupervisor, name: Loomex.TcpReceiverSupervisor},
      {PartitionSupervisor, child_spec: DynamicSupervisor, name: Loomex.TlsReceiverSupervisor},
      {DynamicSupervisor, name: Loomex.SocketSupervisor, strategy: :one_for_one}
    ]
    opts = [strategy: :one_for_one, name: Loomex.Supervisor]
    
    Loomex.Telemetry.init()
    
    Supervisor.start_link(children, opts)
  end
  
  def stop do
    Supervisor.stop Loomex.Supervisor
  end
end