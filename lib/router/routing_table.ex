defmodule Router.RoutingTable do  
  alias Router.MatchRoute
  require Logger
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link __MODULE__, "", [name: :routing_table]
  end
  
  @type request() :: %Request{}
  @type response() :: %Response{}
  @type match_route() :: %MatchRoute{}
  @type query_map() :: %{}
  @type handler_func() :: (request(), query_map() -> response())
  @type route_definition() :: {match_route(), atom(), handler_func()}
  
  @impl true
  def init(_opts) do
    name = :ets.new :routes, [:named_table, :set, :protected, read_concurrency: true]
    case EndpointBuilder.Registry.get_endpoint_builder_route_definitions() do
      routes = [ _ | _ ] ->
        Logger.info "Found #{length routes} routes via EndpointBuilder"
        for {path, method, func} <- routes do
          match_route = MatchRoute.new path
          hash = to_route_hash path, method
          IO.inspect func
          :ets.insert :routes, {hash, match_route, method, func}
        end
      [] -> 
        Logger.info "No route defintions found via EndpointBuilder"
    end
    {:ok, name}
  end
  
  def get_routes, do: 
    :ets.tab2list :routes
  
  @spec match_by_hash(atom(), String.t()) :: :no_match | {:match, route_definition()}
  def match_by_hash(method, path) do
    hash = to_route_hash path, method
    case :ets.lookup :routes, hash do
      [] -> 
        Logger.debug "No match for hash with method and path: #{method}:#{path}"
        :no_match
      [route_definition] -> 
        Logger.debug "Matched path via hash\n#{path} -> #{hash}"
        {_key, path, method, func} = route_definition
        {:match, {path, method, func}}
    end
  end
  
  @spec match_by_route(atom(), String.t()) :: :no_match | {:match, route_definition()}
  def match_by_route(method, path) do
    case get_part_length_matches method, path do
      :no_match -> 
        Logger.debug "No match for route with method and path: #{method}:#{path}"
        :no_match
      {:match, route_definition} ->
        Logger.debug "Matched path via route\n#{method}:#{path}"
        {:match, route_definition}
    end
  end
    
  defp get_part_length_matches(method, path) do
    Logger.debug "Get part length matches: #{inspect method}, #{inspect path}"
    path_parts = String.split path, "/", trim: true
    incoming_length = length path_parts
    select_spec = 
    [
      {{:"$1", %{__struct__: Router.MatchRoute, parts: :"$2"}, :"$3", :"$4"},
      [{:andalso, {:==, {:length, :"$2"}, incoming_length}, {:==, method, :"$3"}}],
      [{{:"$1", :"$2"}}]}
    ]
    case :ets.select :routes, select_spec do
      [] -> :no_match
      matches -> try_match_parts path_parts, matches
    end
  end
  
  defp try_match_parts(path_parts, route_def_matches) do
    Logger.debug "Try match parts: #{inspect path_parts}, #{inspect route_def_matches}"
    [{h, route_def_parts} | rest_defs] = route_def_matches
    case match_path_to_parts path_parts, route_def_parts, h do
      {:match, hash} -> 
        Logger.debug "found match on #{inspect path_parts} with #{inspect route_def_parts}"
        case :ets.lookup :routes, hash do
          [] -> :no_match
          [route_definition] -> 
            {_key, path, method, func} = route_definition
            {:match, {path, method, func}}
        end
      :no_match when rest_defs == [] ->
        Logger.debug "No more defs to check, no match"
        :no_match
      :no_match -> 
        Logger.debug "no match on #{inspect path_parts} with #{inspect route_def_parts}, going next"
        try_match_parts path_parts, rest_defs
    end
  end
  
  defp match_path_to_parts(path_parts, match_parts, hash) do
    Logger.debug "Match path to part: #{inspect path_parts}, #{inspect match_parts}, against hash #{inspect hash}"
    [path_part | rest_path] = path_parts
    [mp | rest_match_parts] = match_parts
    is_param =  mp.is_parameter
    is_match = mp.value == path_part
    case {is_match, is_param} do
      {_, true} when rest_match_parts == [] ->
        Logger.debug "Parameter match on #{inspect path_part} with #{inspect mp.value}\nNo mismatch, match exhausted, hash: #{hash}"
        {:match, hash}
      {true, false} when rest_match_parts == [] ->
        Logger.debug "Match on #{inspect path_part} with #{inspect mp.value}\nNo mismatch, match exhausted, hash: #{hash}"
        {:match, hash}
      {_, true} ->
        Logger.info "Parameter match on #{inspect path_part} with #{inspect mp.value}"
        match_path_to_parts rest_path, rest_match_parts, hash
      {true, false} ->
        Logger.info "Match on #{inspect path_part} with #{inspect mp.value}"
        match_path_to_parts rest_path, rest_match_parts, hash
      {false, false} -> 
        Logger.info "No match found after exhausting #{inspect path_part} with #{inspect mp.value}"
        :no_match
    end
  end
  
  defp to_route_hash(path, method) do
    :erlang.term_to_binary(method) <> :erlang.term_to_binary(path)
      |> Base.encode64
  end
end