defmodule Loomex.Transport.Tls.Receiver do
  alias Loomex.PipelineTask
  require Logger
  
  use GenServer, restart: :transient
    
  @type t() :: %__MODULE__{
    client_socket: :ssl.socket(),
    client_ref: reference(),
    current_buf: binary(),
    request_metadata: Loomex.Transport.receive_state(),
    request_body: Loomex.Transport.receive_state(),
  }
  
  defstruct [
    client_socket: nil,
    client_ref: nil,
    current_buf: <<>>,
    request_metadata: {:incomplete, <<>>},
    request_body: {:incomplete, <<>>},
  ]
  
  def dispatch(client_socket) do
    DynamicSupervisor.start_child {:via, PartitionSupervisor, {Loomex.TlsReceiverSupervisor, self()}}, {__MODULE__, [client_socket]}
  end
  
  def start_link(args, opts \\ []) do
    GenServer.start_link __MODULE__, args, opts
  end
  
  @impl true
  @spec init([:ssl.socket()]) :: {:ok, state :: t()} | {:ok, state :: t(), timeout() | :hibernate | {:continue, continue_arg :: term()}} | :ignore | {:stop, reason :: term()}
  def init([client_socket]) do
    Logger.info "TLS Init"
    initial_state = %__MODULE__{client_socket: client_socket, client_ref: make_ref()}
    {:ok, initial_state, {:continue, :initial_recv}}
  end
  
  @impl true
  def handle_continue(:initial_recv, state = %__MODULE__{client_socket: client_socket, client_ref: client_ref}) do
    Logger.debug "Performing initial receive", socket: client_socket, socket_ref: client_ref
    :ssl.controlling_process client_socket, self()
    :ssl.setopts(client_socket, [active: :once])
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:ssl, _socket, data}, state = %__MODULE__{client_socket: client_socket, client_ref: client_ref}) do
    Logger.debug "Got tls data chunk", socket: client_socket, socket_ref: client_ref
    Logger.info "Data chunk\n#{inspect data}"
    case request_state(data) do
      :incomplete ->
        Logger.debug "Request metadata incomplete", subfunc: "request_state:incomplete", socket: client_socket, socket_ref: client_ref
        :ssl.setopts(client_socket, [active: :once])
        {:noreply, state}
      {:complete, complete_request_no_body} ->
        Logger.debug "Request metadata complete", subfunc: "request_state:complete", socket: client_socket, socket_ref: client_ref
        Logger.info "Complete data\n#{inspect complete_request_no_body}"
        PipelineTask.dispatch [type: :tls, client_socket: client_socket, raw_request_metadata: complete_request_no_body, request_body: {:complete, nil}]
        {:noreply, state}
      {:complete, complete_request, body_data} ->
        Logger.debug "Request metadata complete, body partial", subfunc: "request_state:complete", socket: client_socket, socket_ref: client_ref
        Logger.info "Complete data\n#{inspect complete_request}"
        Logger.info "Current body buffer\n#{inspect body_data}"
        Logger.info "Current body size: #{inspect String.length(body_data)}"
        Logger.info "Total req size: #{inspect String.length(body_data) + String.length(complete_request)}"
        PipelineTask.dispatch [type: :tls, client_socket: client_socket, raw_request_metadata: complete_request, request_body: {:partial, body_data}]
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:ssl_closed, socket}, state) do
    Logger.error "SSL closed", subfunc: "ssl_closed", socket: socket
    {:stop, :normal, state}
  end
  
  @impl true
  def handle_info({:ssl_error, socket, reason}, state) do
    Logger.error "SSL Error", subfunc: "ssl_error", reason: reason, socket: socket
    {:stop, {:shutdown, reason}, state}
  end
  
  @impl true
  def handle_info({:ssl_passive, socket}, state) do
    Logger.debug "SSL Passive message received", subfunc: "ssl_passive", socket: socket
    {:stop, :normal, state}
  end
  
  @impl true
  def terminate(:normal, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.debug "Client socket terminating, stream finished receive :normal", subfunc: "normal", socket: client_socket, socket_ref: client_ref
  end
  
  @impl true
  def terminate(:shutdown, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.error "GenServer TLS Receiver shutdown", subfunc: "shutdown", socket: client_socket, socket_ref: client_ref
  end
  
  @impl true
  def terminate({:shutdown, reason}, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.error "GenServer TLS Receiver shutdown", subfunc: "shutdown", reason: reason, socket: client_socket, socket_ref: client_ref
  end
  
  defp request_state(data) do
    case String.split data, "\r\n\r\n", parts: 2 do
      [_incomplete_request_data] -> 
        :incomplete
      [complete_request_no_body, <<>>] ->
        {:complete, complete_request_no_body}
      [complete_request, body_data] -> 
        {:complete, complete_request, body_data}
    end
  end
end