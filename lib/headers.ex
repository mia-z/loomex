defmodule Headers do
  require Logger
  @default_response_headers %{"Server" => "Loomex", "Connection" => "Keep-Alive"}

  @spec new(String.t()) :: %{}
  def new(headers) when is_binary(headers), do:
    String.split(headers, "\r\n") |> new
  
  @spec new(list(String.t())) :: %{}
  def new(headers) when is_list(headers), do:
    Enum.reduce(headers, %{}, fn header, acc -> 
        case String.split header, ": ", parts: 2 do
          [k, v] -> Map.put(acc, k, v)
          _ -> acc
        end
      end)
  
  def create_default_response_headers, do:
    @default_response_headers 
    |> add_date_header()
  
  def merge(headers1, headers2), do:
    Map.merge(headers1, headers2)
  
  def add(headers, key, value), do: 
    Map.put(headers, key, value)
  
  def remove(headers, key), do:
    Map.delete(headers, key)
  
  def get(headers, header_key), do:
    Map.get(headers, header_key)
  
  # Date: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
  def add_date_header(headers) do
    {:ok, now} = DateTime.now "Etc/UTC"
    formatted_dt = Calendar.strftime now, "%a, %d %m %Y %H:%M:%S GMT"
    add(headers, "Date", formatted_dt)
  end
  
  def format(headers), do:
    Enum.map(headers, fn {k, v} -> [k, ":", " ", v, "\r", "\n"] end)
end