defmodule Headers do
  @spec new(String.t()) :: %{}
  def new(headers) when is_binary(headers), do:
    String.split(headers, "\r\n") |> new
  
  @spec new(list(String.t())) :: %{}
  def new(headers) when is_list(headers) do
    Enum.reduce(headers, %{}, fn header, acc -> 
        case String.split header, ": ", parts: 2 do
          [k, v] -> Map.put(acc, k, v)
          _ -> acc
        end
      end)
  end
  
  def add(headers, key, value), do: 
    Map.put(headers, key, value)
  
  def remove(headers, key), do:
    Map.delete(headers, key)
  
  def get(headers, header_key), do:
    Map.get(headers, header_key)
  
  def format(headers), do:
    Enum.map(headers, &("#{elem(&1, 0)}: #{elem(&1, 1)}"))
    |> Enum.join("\r\n")
    |> then(&(&1 <>"\r\n"))
end