defmodule Loomex.PipelineTask do
  import Loomex.Transport

  require Logger

  @type t() :: %__MODULE__{
    socket_type: :tcp | :tls,
    client_socket: :socket.socket() | :ssl.socket(),
    request_metadata: binary(),
    request_body_status: Loomex.Transport.receive_state(),
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
    client_socket: nil,
    request_metadata: "",
    request_body_status: {:incomplete, nil},
    transport_module: Loomex.Transport.Tcp,
  ] 
  
  def dispatch(args) do
    Task.Supervisor.start_child({:via, PartitionSupervisor, {Loomex.PipelineTaskSupervisor, self()}}, __MODULE__, :start, [args[:type], args[:client_socket], args[:raw_request_metadata], args[:request_body]], [])
  end
  
  def start(:tcp, client_socket, req_meta, body) do
    run %__MODULE__{socket_type: :tcp, client_socket: client_socket, request_body_status: body, request_metadata: req_meta}
  end
  
	def start(:tls, client_socket, req_meta, body) do
    run %__MODULE__{transport_module: Loomex.Transport.Tls, socket_type: :tls, client_socket: client_socket, request_body_status: body, request_metadata: req_meta}
	end
	
	def run(_initial_data = %__MODULE__{request_metadata: raw_request, request_body_status: body, transport_module: transport, client_socket: client_socket}) do
	  initial_response = Response.new()
	  with {:ok, structured_request} <- handle_request(raw_request, body),
			{:ok, pre_route_middleware_response} <- pre_route_middleware(structured_request, initial_response),
      {:ok, route_response} <- handle_route(structured_request, pre_route_middleware_response),
 			{:ok, post_route_middleware_response} <- post_route_middleware(structured_request, route_response),
      formatted_response <- format_final_response(post_route_middleware_response),
      :ok <- handle_finalize(transport, client_socket, formatted_response) do
        Logger.debug "Final response object: #{inspect post_route_middleware_response}"
        Logger.debug "Formatted response: #{formatted_response}"
    else
      error ->
        handle_error transport, client_socket, error 
    end
    rescue 
      error ->
        handle_exception transport, client_socket, error
	end
	
	defp handle_request(raw_request, body) do
    Request.handle_request(raw_request, body)
	end
	
	defp pre_route_middleware(_request, initial_resposne) do
	  response_after_pre_route_middleware = initial_resposne
    {:ok, response_after_pre_route_middleware}
	end
	
	defp handle_route(request, current_response) do
    Router.handle_route(request, current_response)
	end
	
	defp post_route_middleware(_request, current_response) do
	  response_after_post_route_middleware = current_response
	  {:ok, response_after_post_route_middleware}
	end
	
	defp format_final_response(final_response_state) do
    Response.format_response(final_response_state)
	end
	
	defp handle_finalize(transport, client_socket, formatted_response) do
	  transport.send_resp client_socket, formatted_response
    transport.close_socket client_socket
	end
	
	defp handle_error(transport, client_socket, error) do
	  Logger.error "Pipeline error", reason: error
    transport.send_resp client_socket, ["HTTP/1.1 500 INTERNAL SERVER ERROR", "\r", "\n", "\r", "\n"]
    transport.close_socket client_socket
	end
	
	defp handle_exception(transport, client_socket, error) do
	  Logger.error "Pipeline exception", reason: error
    transport.send_resp client_socket, ["HTTP/1.1 500 INTERNAL SERVER ERROR", "\r", "\n", "\r", "\n"]
    transport.close_socket client_socket
	end
end