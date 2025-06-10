defmodule Request.RequestPath do
  
  @type t() :: %__MODULE__{
    full_path: binary(),
    parts: %{
      integer() => binary()
    }
  }
  defstruct [
    full_path: nil, 
    parts: %{}
  ]
  
  @spec parse(binary()) :: t()
  def parse(path) do
    indexed_parts = String.split(path, "/", trim: true)
    |> Enum.with_index(1)
    |> Enum.reduce(Map.new(), fn {part, index}, acc -> Map.put(acc, index, part) end)
    %__MODULE__{ full_path: path, parts: indexed_parts}
  end
end