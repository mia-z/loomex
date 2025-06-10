defmodule Loomex.Pipeline do
  import Loomex.Transport
  @moduledoc """
    Pipeline Module
    """
  require Logger

  @type t() :: %__MODULE__{
    socket_type: :tcp | :tls,
    pipeline_context: pid(),
    client_socket: :socket.socket() | :ssl.socket(),
    request_metadata: binary(),
    request_body_status: Loomex.Transport.receive_state(),
    structured_response: %Response{},
    transport_module: Loomex.Transport.t(),
  }
  
  @type dispatch_option() :: 
    {:port, integer()} |
    {:client_socket, :socket.socket() | :ssl.socket()} |
    {:type, :tcp | :tls} |
    {:request_metadata, binary()} |
    {:request_body_status, Loomex.Transport.receive_state()}
    
  @type dispatch_args() :: [dispatch_option()]
  
  defstruct [
    socket_type: :tcp,
    pipeline_context: nil,
    client_socket: nil,
    request_metadata: "",
    request_body_status: {:incomplete, nil},
    structured_response: %Response{},
    transport_module: Loomex.Transport.Tcp,
  ] 
  
  use GenServer, restart: :transient

  @spec dispatch(dispatch_args()) :: DynamicSupervisor.on_start_child()
  def dispatch(dispatch_args) do
    # DynamicSupervisor.start_child {:via, PartitionSupervisor, {Loomex.PipelineSupervisor, Loomex.SocketSupervisor}}, {Loomex.Pipeline, dispatch_args}
    DynamicSupervisor.start_child Loomex.PipelineSupervisor, {Loomex.Pipeline, dispatch_args}
  end

  @spec start_link(args :: dispatch_args(), opts :: []) :: GenServer.on_start()
  def start_link(args, opts \\ []) do
    GenServer.start_link __MODULE__, [args[:type], args[:client_socket], args[:raw_request_metadata], args[:request_body]], opts
  end
  
  @impl true
  def init([:tcp, client_socket, req_meta, body]) do
    Logger.debug "Init Pipeline tcp"
    initial_state = %__MODULE__{socket_type: :tcp, client_socket: client_socket, pipeline_context: self(), request_body_status: body, request_metadata: req_meta}
    {:ok, initial_state, {:continue, :run_pipeline}}
  end
  
  @impl true
  def init([:tls, client_socket, req_meta, body]) do
    Logger.debug "Init Pipeline tls", socket: client_socket
    initial_state = %__MODULE__{transport_module: Loomex.Transport.Tls, socket_type: :tls, client_socket: client_socket, pipeline_context: self(), request_body_status: body, request_metadata: req_meta}
    {:ok, initial_state, {:continue, :run_pipeline}}
  end

  @impl true
  def handle_continue(:run_pipeline, %__MODULE__{ request_metadata: raw_request, request_body_status: body, pipeline_context: pipeline_context } = state) do
    with {:ok, structured_request} <- Request.handle_request(raw_request, body, pipeline_context),
      {:ok, structured_response} <- Router.handle_route(structured_request),
      {:ok, formatted_response} <- Response.handle_response(structured_response, pipeline_context) do
        Logger.debug "Constructed forrmatted response: #{inspect formatted_response}"
        {:noreply, state, {:continue, {:finalize, formatted_response}}}
    else
      {:error, section, reason} -> 
        Logger.error "Error in request: #{inspect reason}"
        {:stop, {:shutdown, {:pipeline_task_error, section, reason}}, state}
    end
  end
  
  @impl true
  def handle_continue({:finalize, formatted_response}, state = %__MODULE__{ client_socket: client_socket, transport_module: transport }) do
    transport.send_resp client_socket, formatted_response
    transport.close_socket client_socket
    {:stop, :normal, state}
  end
  
  @impl true
  def handle_call(:get_pipeline_socket, _from, state = %__MODULE__{transport_module: transport, client_socket: client_socket}) do
    {:reply, {transport, client_socket}, state}
  end
  
  @impl true
  def terminate(:normal, _state = %__MODULE__{ pipeline_context: pipeline_context }) do
    Logger.debug "Pipeline finished normally #{inspect pipeline_context}"
  end
  
  @impl true
  def terminate({:shutdown, {:pipeline_task_error, task_type, reason}}, %__MODULE__{ transport_module: transport, client_socket: client_socket } = _state) do
      transport.send_resp client_socket, ["HTTP/1.1 500 INTERNAL SERVER ERROR", "\r", "\n", "\r", "\n"]
      transport.close_socket client_socket
      Logger.error "Pipeline finished abnormally at #{inspect task_type}", subfunc: "shutdown", reason: reason, socket: client_socket
  rescue
    err -> 
      Logger.error "Unable to signal client socket 500", reason: err, socket: client_socket, socket_ref: make_ref()
  end
  
  @impl true
  def terminate({:shutdown, reason}, %__MODULE__{client_socket: client_socket}) do
    Logger.warning "Unexpected termination in #{inspect self()}", subfunc: "shutdown", reason: reason, socket: client_socket
  end
  
  @impl true
  def terminate(reason, %__MODULE__{client_socket: client_socket}) do
    Logger.warning "Unexpected termination in #{inspect self()}", subfunc: "shutdown", reason: reason, socket: client_socket
  end
  
  def get_pipeline_socket(pid) do
    GenServer.call(pid, :get_pipeline_socket)
  end
end