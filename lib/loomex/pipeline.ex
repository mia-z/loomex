defmodule Loomex.Pipeline do
  alias Loomex.Pipeline
  @moduledoc """
    Pipeline Module
    """
  require Logger

  defstruct socket_type: nil,
    pipeline_context: nil,
    client_socket: nil,
    raw_request: nil,
    structured_response: nil
  
  use GenServer, restart: :temporary

  def dispatch({:tcp_socket, client_socket}) do
    {:ok, pid} = DynamicSupervisor.start_child Loomex.PipelineSupervisor, {Pipeline, [:tcp_socket, client_socket]}
    :gen_tcp.controlling_process client_socket, pid
  end

  def dispatch({:ssl_socket, final_socket}) do
    {:ok, pid} = DynamicSupervisor.start_child Loomex.PipelineSupervisor, {Pipeline, [:ssl_socket, final_socket]}
    :ssl.controlling_process final_socket, pid
    :ssl.setopts final_socket, active: true
  end

  def start_link(args, opts \\ []) do
    Logger.debug "Starting pipeline\nargs: #{inspect args}\nopts: #{inspect opts}"
    GenServer.start_link __MODULE__, args, opts
  end
  
  @impl true
  def init([:tcp_socket, client_socket]) do
    Logger.debug "Init Pipeline\ninitial_args: #{inspect client_socket}"
    {:ok, %Pipeline{ client_socket: client_socket, socket_type: :tcp_socket, pipeline_context: self() }}
  end

  @impl true
  def init([:ssl_socket, client_socket]) do
    Logger.debug "Init Pipeline\ninitial_args: #{inspect client_socket}"
    {:ok, %Pipeline{ client_socket: client_socket, socket_type: :ssl_socket, pipeline_context: self() }}
  end
  
  @impl true
  def handle_info({:tcp, client_socket, raw_request}, state) do
    Logger.debug "Received connection message for tcp client socket: #{inspect client_socket}"
    {:noreply, %Pipeline{ state | raw_request: raw_request }, {:continue, :run_pipeline}}
  end

  @impl true
  def handle_info({:tcp_closed, listen_socket}, %Pipeline{pipeline_context: pipeline_context} = state) do
    Logger.debug "Pipeline #{inspect pipeline_context} client socket #{inspect listen_socket} received external close"
    {:stop, {:shutdown, :tcp_external}, state}
  end

  @impl true
  def handle_info({:tcp_error, listen_socket, reason}, state) do
    Logger.debug "TCP socket #{inspect listen_socket} error: #{inspect reason}"
    {:stop, {:shutdown, :tcp_error}, state}
  end

  @impl true
  def handle_info({:ssl, client_socket, raw_request}, state) do
    Logger.debug "Received connection message for ssl client socket: #{inspect client_socket}"
    {:noreply, %Pipeline{ state | raw_request: raw_request }, {:continue, :run_pipeline}}
  end

  @impl true
  def handle_info({:ssl_closed, listen_socket}, %Pipeline{pipeline_context: pipeline_context} = state) do
    Logger.debug "Pipeline #{inspect pipeline_context} client socket #{inspect listen_socket} received external close"
    {:stop, {:shutdown, :ssl_external}, state}
  end

  @impl true
  def handle_info({:ssl_error, listen_socket, reason}, state) do
    Logger.error "SSL socket #{inspect listen_socket} error: #{inspect reason}"
    {:stop, {:shutdown, :ssl_error}, state}
  end
  
  @impl true
  def handle_continue(:run_pipeline, %Pipeline{ raw_request: raw_request } = state) do
    with {:ok, structured_request} <- Request.handle_request(raw_request),
      {:ok, structured_response} <- Router.handle_route(structured_request),
      {:ok, formatted_response} <- Response.handle_response(structured_response) do
        {:noreply, state, {:continue, {:finalize, formatted_response}}}
    else
      {:error, :request, reason} -> 
        Logger.error "Error in request: #{inspect reason}"
        {:stop, {:shutdown, {:pipeline_task_error, :request, reason}}, state}
      {:error, :router, reason} -> 
        Logger.error "Error in router: #{inspect reason}"
        {:stop, {:shutdown, {:pipeline_task_error, :router, reason}}, state}
      {:error, :response, reason} -> 
        Logger.error "Error in response: #{inspect reason}"
        {:stop, {:shutdown, {:pipeline_task_error, :response, reason}}, state}
    end
  end
  
  @impl true
  def handle_continue({:finalize, formatted_response}, state = %Pipeline{ client_socket: client_socket, socket_type: :tcp_socket }) do    
    :gen_tcp.send client_socket, formatted_response
    :gen_tcp.close client_socket
    {:stop, :normal, state}
  end

  @impl true
  def handle_continue({:finalize, formatted_response}, state = %Pipeline{ client_socket: client_socket, socket_type: :ssl_socket }) do
    :ssl.send client_socket, formatted_response
    :ssl.close client_socket
    {:stop, :normal, state}
  end
  
  @impl true
  def terminate(:normal, _state = %Pipeline{ pipeline_context: pipeline_context }) do
    Logger.debug "Pipeline finished normally #{inspect pipeline_context}"
  end

  @impl true
  def terminate({:shutdown, {:pipeline_task_error, task_type, reason}}, %Pipeline{ socket_type: socket_type, client_socket: client_socket, pipeline_context: pipeline_context } = _state) do
    try do
      case socket_type do
        :tcp_socket ->
          :gen_tcp.send client_socket, "HTTP/1.1 500 INTERNAL SERVER ERROR\r\n\r\n"
          :gen_tcp.close client_socket
        :ssl_socket -> 
          :ssl.send client_socket, "HTTP/1.1 500 INTERNAL SERVER ERROR\r\n\r\n"
          :ssl.close client_socket
      end
    rescue
      _ -> 
        Logger.error "Unable to signal client socket 500"
    end
    Logger.error "Pipeline finished abnormally #{inspect pipeline_context}\nAt: #{inspect task_type}\nReason #{inspect reason}"
  end
  
  @impl true
  def terminate(reason, state = %Pipeline{}) do
    Logger.warning "Unexpected termination in #{inspect self()}\nreason: #{inspect reason}\nstate: #{inspect state}"
  end
end