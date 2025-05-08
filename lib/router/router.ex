defmodule Router do
  alias Response.ResponseCode
  alias Request.RequestRoute
  alias Router.RoutingTable
  require Logger

  @type request() :: %Request{}
  @type response() :: %Response{}
  
  @spec handle_route(request()) :: {:ok, response()} | {:error, :router, term()}
  def handle_route(structured_request = %Request{}) do
    Logger.debug "Starting router handle with data #{inspect structured_request} on pipeline #{inspect self()}"
    structured_response = handle structured_request
    Logger.debug "Finished router handle on pipeline #{inspect self()}"
    structured_response
  end

  @spec handle_route(request()) :: {:ok, response()} | {:error, :router, term()}
  defp handle(structured_request = %Request{method: method, route: %RequestRoute{ full_path: path }}) do
    try do
      match = case RoutingTable.match_by_hash method, path do
        :no_match -> case RoutingTable.match_by_route method, path do
          :no_match -> :not_found
          {:match, route_definition} -> {:found, route_definition}
        end
        {:match, route_definition} -> {:found, route_definition}
      end
  
      structured_response = case match do
        {:found, route_definition} -> handle_found structured_request, route_definition
        :not_found -> handle_not_found structured_request
      end
      
      {:ok, structured_response}
    rescue
      err ->
        Logger.error "Error in handle_route/1\n#{inspect err}"
        {:error, :router, err}
    end
  end
  
  defp handle_found(%Request{} = request, route_definition) do
    Logger.debug "Match found, running handler delegate"
    {_route, _method, handler_delegate} = route_definition
    delegate_res = handler_delegate.(request, Request.get_query_map(request))
    # TODO: Validate handler result here
    # 
    Logger.debug "Handler delegate returned: #{inspect delegate_res}"
    delegate_res
  end
  
  defp handle_not_found(%Request{} = _request) do
    Logger.debug "Match not found, returning 404 response"
    %Response{response_code: ResponseCode.not_found, body: "Not found"}
  end
end