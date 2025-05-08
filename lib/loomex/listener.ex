defmodule Loomex.Listener do
  alias Loomex.SSLHelper
  require Logger
    
  use GenServer
  
  @type standard_handle_info_return() :: 
    {:noreply, new_state :: t()} | {:noreply, new_state :: t(), timeout() | :hibernate | {:continue, continue_arg :: term()}} |
    {:stop, reason :: term(), new_state :: t()}
  
  @type standard_handle_continue_return() :: 
    standard_handle_info_return()
  
  @type listener_handle_info() :: 
    :timeout |
    {:'$socket', listener_socket :: :socket.socket(), :select, accept_ref :: reference()} |
    {:'$socket', listener_socket :: :socket.socket(), :completion, {accept_ref :: reference(), completion_info :: :socket.completion_info()}} |
    {:'$socket', listener_socket :: :socket.socket(), :abort, reason :: term()} |
    {:EXIT, pid :: pid(), reason :: term()} |
    term()
  
  @type t() :: %__MODULE__{
    port: integer(),
    listener_socket: :socket.socket(),
    current_accept_ref: reference(),
    mode: :tcp | :tls,
    transport_module: Loomex.Transport.t()
  }

  defstruct [
    port: nil,
    listener_socket: nil,
    current_accept_ref: nil,
    mode: :tcp,
    transport_module: Loomex.Transport.Tcp
  ]
  
  def start_link(args, opts \\ []) do
    Logger.debug "Link started for SocketListener\n#{inspect args}"
    GenServer.start_link __MODULE__, args, opts
  end
  
  @impl true
  def init(init_args) do
    Logger.debug "SocketListener init\ninit_args: #{inspect init_args}"

    port = Keyword.get init_args, :port, 4044
    mode = Keyword.get init_args, :mode, :tcp
    
    transport = case mode do
      :ssl ->
        Logger.debug "SocketListener starting with TLS"
        SSLHelper.create()
        |> SSLHelper.set_certs(port)
        Loomex.Transport.Tls
      :tcp -> 
        Loomex.Transport.Tcp
    end
  
    initial_state = %__MODULE__{
      current_accept_ref: nil,
      transport_module: transport,
      mode: mode,
      port: port
    }
    
    with {:ok, listener_socket} <- :socket.open(:inet, :stream, :tcp),
      :ok <- :socket.setopt(listener_socket, :socket, :reuseaddr, true),
      :ok <- :socket.bind(listener_socket, %{family: :inet, port: port, addr: :loopback}),
      initial_state <- %__MODULE__{initial_state | listener_socket: listener_socket},
      :ok <- :socket.listen(listener_socket, 1024) do
        Logger.debug "Performing initial accept."
        initial_ref = make_ref()
        case transport.accept listener_socket, initial_ref, port do
          {:select, tag, ^initial_ref} -> 
            Logger.debug ":socket.accept (:select) with tag #{inspect tag} for same ref\nStoring ref, and going async.", subfunc: "accept:select", socket: listener_socket, socket_ref: initial_ref
            {:ok, %__MODULE__{ initial_state | current_accept_ref: initial_ref}}
          {:completion, tag, ^initial_ref} ->
            Logger.warning ":socket.accept (:completion) with tag #{inspect tag} for same ref #{inspect initial_ref}\nWaiting for '$socket' completion message.", subfunc: "accept:completion", socket: listener_socket, socket_ref: initial_ref
            Logger.warning "Not implemented completion events"
            {:stop, {:shutdown, :not_implemented}, initial_state}
          {:error, reason} ->
            Logger.error "Error after immediate accept", subfunc: "accept:error", reason: reason
            {:stop, {:shutdown, reason}, initial_state}
        end
    else
      {:error, :closed} ->
        Logger.error "Couldnt start SocketListener, socket closed or unavailable"
        {:stop, {:shutdown, :socket_closed}}
      {:error, reason} -> 
        Logger.error "Couldnt start SocketListener, reason: #{inspect reason}"
        {:stop, {:shutdown, :error, reason}}
    end    
  end
  
  @impl true
  def handle_info({:'$socket', listener_socket, :select, current_ref}, state = %__MODULE__{listener_socket: state_socket, transport_module: transport, port: port, current_accept_ref: current_state_accept_ref}) 
    when listener_socket == state_socket and current_ref == current_state_accept_ref do
    Logger.debug "Got async accept message"
    case transport.accept listener_socket, current_ref, port do
      {:select, tag, current_ref} -> 
        Logger.debug "Async :socket.accept (:select) with tag #{inspect tag} for same ref\nStoring ref, waiting for messages...", subfunc: "accept:select", socket: listener_socket, socket_ref: current_ref
        {:noreply, %__MODULE__{ state | current_accept_ref: current_ref}}
      {:error, reason} ->
        Logger.error "Error after async message for ref", subfunc: "accept:error", socket: listener_socket, socket_ref: current_ref, reason: reason
        {:stop, {:shutdown, reason}, state}
    end
  end
  
  @impl true
  def terminate(reason, state) do
    case state do
      %{listener_socket: listener_socket} when listener_socket != nil ->
        Logger.debug "Listener terminated; general", reason: reason, socket: listener_socket
        :socket.close listener_socket
      _ ->
        # This might happen if init failed before listener_socket was put in state
        Logger.error "Listener socket not found in state or was nil during termination.", reason: reason
    end
  end
end