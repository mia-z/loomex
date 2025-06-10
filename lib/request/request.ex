defmodule Request do
  alias Request.RequestPath
  require Logger
  
  @type query_params() :: map()
  @type route_params() :: map()
  
  @type t() :: %__MODULE__{
    pipeline_context: pid(),
    path: RequestPath.t(),
    method: Method.t(),
    query_params: query_params(),
    route_params: route_params(),
    headers: Headers.t(),
    body: Request.Body.t()
  }
  defstruct [
    pipeline_context: nil,
    path: nil, 
    method: nil, 
    query_params: %{}, 
    route_params: %{}, 
    headers: %{}, 
    body: %Request.Body{}
  ]

  @spec handle_request(request_metadata :: String.t(), current_body_status :: Loomex.Transport.receive_state(), pipeline_context :: pid()) 
    :: {:ok, t()} | {:error, :request, term()}
  def handle_request(request_metadata, current_body_status, pipeline_context) do
    Logger.debug "Starting request handle with data #{inspect request_metadata} on pipeline #{inspect self()}"
    with {:ok, parsed_request_data} <- handle(request_metadata, pipeline_context),
      initial_body <- Request.Body.prepare_initial(current_body_status, parsed_request_data) do
        {:ok, %__MODULE__{parsed_request_data | body: initial_body}}
    else
      {:error, :request, reason} ->
        {:error, :request, reason}
    end
  end
  
  @spec handle(binary(), pid()) :: {:ok, t()} | {:error, :request, term()}
  defp handle(request_metadata, pipeline_context) do
    with {raw_request_line, raw_headers} <- split_request_line_and_headers(request_metadata),
      {raw_method, raw_path} <- split_request_line(raw_request_line),
      {path, query} <- split_path_and_query(raw_path),
      request_path <- RequestPath.parse(path),
      headers <- Headers.parse(raw_headers),
      method <- Method.parse(raw_method),
      parsed_query <- URI.decode_query(query) do
        {:ok, %__MODULE__{
          pipeline_context: pipeline_context,
          path: request_path,
          method: method,
          query_params: parsed_query,
          route_params: Map.new(),
          headers: headers
        }}
    else
      {:error, :request, reason} ->
        {:error, :request, reason}
    end
  end
  
  defp split_request_line_and_headers(raw_metadata) do
    case String.split raw_metadata, "\r\n" do
      [request_line | headers] ->
        {request_line, headers}
      _ ->
        {:error, :request, "Couldnt split request line and headers"}
    end
  end
  
  defp split_request_line(raw_request_line) do
    case String.split raw_request_line, " ", parts: 3 do
      [method, path, _protocol] ->
        {method, path}
      _ ->
        {:error, :request, "Couldnt split request line into parts"}
    end
  end
  
  defp split_path_and_query(raw_path) do
    case String.split raw_path, "?", parts: 2 do
      [path, query] -> 
        {path, query}
      [path] -> 
        {path, ""}
      _ ->
        {:error, :request, "Couldnt split route into path and query"}
    end
  end
end
