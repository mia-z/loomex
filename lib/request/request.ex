defmodule Request do
  alias Request.RequestRoute
  require Logger
  
  @type request() :: %Request{}
  defstruct [:route, :method, :query_string, :headers, :body]

  @spec handle_request(binary()) :: {:ok, request()} | {:error, :request, term()}
  def handle_request(raw_request) do
    Logger.debug "Starting request handle with data #{inspect raw_request} on pipeline #{inspect self()}"
    structured_request = handle raw_request
    Logger.debug "Finished request handle on pipeline #{inspect self()}"
    structured_request
  end
  
  @spec handle(binary()) :: {:ok, request()} | {:error, :request, term()}
  defp handle(request) do
    try do
      [request_line | headers] = String.split request, ~r"\r\n"
  
      [method, path, _protocol] = String.split request_line, " ", parts: 3
          
      [route, query_string] = case String.split path, "?", parts: 2 do
        [route, query] -> [route, query]
        [route] -> [route, ""]
      end

      {:ok, %Request{
        route: RequestRoute.new(route),
        method: String.to_atom(method),
        query_string: query_string,
        headers: Headers.new(headers),
        body: nil
      }}
    rescue
      err ->
        Logger.error "", reason: err
        {:error, :request, err}
    end
  end
  
  def get_query_map(%Request{ query_string: query_string }) when is_binary query_string do
    query_string
    |> get_sections
    |> get_pairs
  end
  
  defp get_sections(""), do: []
  defp get_sections(query_string), do: (String.split query_string, "&")

  defp get_pairs([]), do: Map.new
  defp get_pairs(sections) do 
    Enum.reduce sections, Map.new, fn section, acc ->
        case String.match? section, ~r/([\w]{1,}=[\w]{1,})/ do
          true -> 
            [k, v] = String.split section, "=", parts: 2
            Map.put acc, k, v
          false -> acc
        end
      end
  end
end
