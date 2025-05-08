defmodule Loomex.Transport.Tcp.Receiver do
  alias Loomex.Pipeline
  require Logger
  
  use GenServer, restart: :transient

  @type t() :: %__MODULE__{
    client_socket: :socket.socket(),
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
    DynamicSupervisor.start_child {:via, PartitionSupervisor, {Loomex.TcpReceiverSupervisor, Loomex.Listener}}, {__MODULE__, [client_socket]}
  end
  
  def start_link(args, opts \\ []) do
    GenServer.start_link __MODULE__, args, opts
  end
  
  @impl true
  @spec init([:socket.socket()]) :: {:ok, state :: t()} | {:ok, state :: t(), timeout() | :hibernate | {:continue, continue_arg :: term()}} | :ignore | {:stop, reason :: term()}
  def init([client_socket]) do
    initial_state = %__MODULE__{client_socket: client_socket, client_ref: make_ref()}
    {:ok, initial_state, {:continue, :initial_recv}}
  end

  @impl true
  def handle_continue(:initial_recv, state = %__MODULE__{client_socket: client_socket, client_ref: client_ref}) do
    Logger.debug "Performing initial receive", socket: client_socket, socket_ref: client_ref
    case handle_recv client_socket, client_ref do
      {:data, data} ->
        Logger.info "Got initial data chunk\n#{inspect data}"
        Logger.debug "Received initial data", subfunc: "handle_recv:data", socket: client_socket, socket_ref: client_ref
        case request_state data do
          :incomplete ->
            Logger.debug "Got potentially incomplete data", subfunc: "handle_recv:request_state:incomplete", socket: client_socket, socket_ref: client_ref
            :socket.setopt client_socket, :otp, :controlling_process, self()
            {:noreply, %__MODULE__{state | current_buf: data, request_metadata: {:incomplete, data}}}
          {:complete, request_data} ->
            Logger.debug "Got full request data, no body", subfunc: "handle_recv:request_state:complete", socket: client_socket, socket_ref: client_ref
            {:noreply, %__MODULE__{state | current_buf: data, request_metadata: {:complete, request_data}, request_body: {:complete, <<>>}}, {:continue, :request_metadata_ready}}
          {:complete, request_data, partial_or_full_body} ->
            Logger.debug "Got full request data, some or all body", subfunc: "handle_recv:request_state:complete", socket: client_socket, socket_ref: client_ref            
            {:noreply, %__MODULE__{state | current_buf: data, request_metadata: {:complete, request_data}, request_body: {:partial, partial_or_full_body}}, {:continue, :request_metadata_ready}}
        end
      :waiting ->
        Logger.debug "Got wait signal from initial receive, handing over", subfunc: "handle_recv:waiting", socket: client_socket, socket_ref: client_ref
        :socket.setopt client_socket, :otp, :controlling_process, self()
        {:noreply, state}
      {:error, reason} ->
        Logger.debug "Got error from initial receive", subfunc: "handle_recv:request_state:complete", socket: client_socket, socket_ref: client_ref, reason: reason
        {:stop, {:shutdown, reason}, state}
    end
  end
  
  @impl true
  def handle_continue(:request_metadata_ready, state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, request_body: request_body, request_metadata: request_metadata}) do
    Logger.debug "Request metadata finalized, computing request body", subfunc: "request_metadata_ready", socket: client_socket, client_ref: client_ref
    Logger.info "Final request metadata\n#{inspect elem(request_metadata, 1)}"
    Logger.info "Current request body\n#{inspect elem(request_body, 1)}"
    Pipeline.dispatch [type: :tcp, client_socket: client_socket, raw_request_metadata: elem(request_metadata, 1), request_body: request_body]
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:'$socket', _message_socket, :select, _message_ref}, state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: current_buf}) do
    Logger.debug "Got :select message", socket: client_socket, socket_ref: client_ref
    case handle_recv client_socket, client_ref do
      {:data, data} ->
        Logger.debug "Received continued data", subfunc: "handle_recv:data", socket: client_socket, socket_ref: client_ref
        Logger.info "Got async data chunk\n#{inspect data}"
        adjusted_buffer = current_buf <> data
        case request_state adjusted_buffer do
          :incomplete ->
            Logger.debug "Got potentially incomplete data", subfunc: "handle_recv:data:request_state:incomplete", socket: client_socket, socket_ref: client_ref
            Logger.info "Current data state: #{inspect :incomplete}\n#{inspect(adjusted_buffer)}"
            {:noreply, %__MODULE__{state | current_buf: adjusted_buffer, request_metadata: {:partial, adjusted_buffer}, request_body: {:incomplete, <<>>}}}
          {:complete, request_data} ->
            Logger.debug "Got full request data, no body", subfunc: "handle_recv:data:request_state:complete", socket: client_socket, socket_ref: client_ref
            {:noreply, %__MODULE__{state | current_buf: adjusted_buffer, request_metadata: {:complete, request_data}, request_body: {:complete, <<>>}}, {:continue, :request_metadata_ready}}
          {:complete, request_data, partial_or_full_body} ->
            Logger.debug "Got full request data, some or all body", subfunc: "handle_recv:data:request_state:complete", socket: client_socket, socket_ref: client_ref
            {:noreply, %__MODULE__{state | current_buf: adjusted_buffer, request_metadata: {:complete, request_data}, request_body: {:partial, partial_or_full_body}}, {:continue, :request_metadata_ready}}
        end
      :waiting ->
        Logger.debug "Got wait signal from initial receive, handing over", subfunc: "handle_recv:waiting", socket: client_socket, socket_ref: client_ref
        {:noreply, state}
      {:error, reason} ->
        Logger.debug "Got error from initial receive", subfunc: "handle_recv:error", socket: client_socket, socket_ref: client_ref, reason: reason
        {:stop, {:shutdown, reason}, state}
    end
  end
  
  @impl true
  def handle_info({:'$socket', _message_socket, :abort, reason}, state = %__MODULE__{client_socket: client_socket, client_ref: client_ref}) do
    Logger.debug "Client socket got abort message, stopping process", reason: reason, subfunc: "abort", socket: client_socket, socket_ref: client_ref
    {:stop, :normal, state}
  end
  
  @impl true
  def terminate(:normal, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.debug "Client socket terminating, stream finished receive :normal", subfunc: "normal", socket: client_socket, socket_ref: client_ref
  end
  
  @impl true
  def terminate(:shutdown, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.error "GenServer TCP Receiver shutdown", subfunc: "shutdown", socket: client_socket, socket_ref: client_ref
  end
  
  @impl true
  def terminate({:shutdown, reason}, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.error "GenServer TCP Receiver shutdown", subfunc: "shutdown", reason: reason, socket: client_socket, socket_ref: client_ref
  end
  
  @impl true
  def terminate(catch_all_reason, _state = %__MODULE__{client_socket: client_socket, client_ref: client_ref, current_buf: _current_buf}) do
    Logger.error "GenServer TCP Receiver shutdown catch all", subfunc: "catch_all_reason", reason: catch_all_reason, socket: client_socket, socket_ref: client_ref
  end
  
  defp handle_recv(client_socket, client_ref) do
    case :socket.recv client_socket, 8192, [], client_ref do
      {:ok, data} ->
        {:data, data}
      {:select, {:select_info, _tag, ^client_ref}} ->
        :waiting
      {:select, {{:select_info, _tag, ^client_ref}, data}} ->
        {:data, data}
      {:error, reason} ->
        Logger.error "handle_recv got error", subfunc: "recv:error", reason: reason, socket: client_socket, socket_ref: client_ref
        {:error, reason}
      res ->
        Logger.warning "handle_recv got unexpected response from :socket.recv\n#{inspect res}", subfunc: "UNHANDLED", socket: client_socket, socket_ref: client_ref
    end
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