defmodule Router do
  alias EndpointBuilder.EndpointResult
  alias Request.RequestPath
  alias Router.RoutingTable
  require Logger

  @spec handle_route(Request.t(), Response.t()) :: {:ok, Response.t()} | {:error, :router, term()}
  def handle_route(structured_request, current_response) do
    Logger.debug "Starting router handle with data #{inspect structured_request} on pipeline #{inspect self()}"
    structured_response = handle structured_request, current_response
    Logger.debug "Finished router handle on pipeline #{inspect self()}"
    structured_response
  end

  @spec handle(Request.t(), Response.t()) :: {:ok, Response.t()} | {:error, :router, term()}
  defp handle(structured_request = %Request{method: method, path: %RequestPath{ full_path: path }}, current_response) do
    match = case RoutingTable.match_by_hash method, path do
      :no_match -> case RoutingTable.match_by_route method, path do
        :no_match -> :not_found
        {:match, route_definition} -> {:found, route_definition}
      end
      {:match, route_definition} -> {:found, route_definition}
    end

    endpoint_result = case match do
      {:found, route_definition} -> handle_found structured_request, route_definition
      :not_found -> handle_not_found structured_request
    end
    
    {:ok, Response.apply_endpoint_result(current_response, endpoint_result)}
  rescue
    err ->
      Logger.error "Error in handle_route/2\n#{inspect err}"
      {:error, :router, err}
  end
  
  defp handle_found(%Request{} = request, route_definition) do
    Logger.debug "Match found, running handler delegate"
    {match_route, _method, handler_delegate} = route_definition
    route_params = map_route_params(request, match_route)

    request = %Request{ request | route_params: route_params}
     
    delegate_res = handler_delegate.(request)
        
    Logger.debug "Handler delegate returned: #{inspect delegate_res}"
    delegate_res
  end
  
  defp handle_not_found(%Request{} = _request) do
    Logger.debug "Match not found, returning 404 response"
    EndpointResult.not_found()
  end
  
  defp map_route_params(%Request{path: path}, match_route) do
    case Router.MatchRoute.get_parameter_parts(match_route) do
      [] -> Map.new()
      found_params -> 
        Map.merge(found_params, path.parts, fn _key, param_key, param_value ->
          {param_key, param_value}
        end)
        |> Enum.filter(fn {_k, v} ->  is_tuple v end)
        |> Enum.reduce(Map.new(), fn {_key, {param_key, param_value}}, acc ->
          Map.put(acc, param_key, param_value)
        end)
    end    
  end
end