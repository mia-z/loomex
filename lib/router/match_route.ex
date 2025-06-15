defmodule Router.MatchRoute do
  require Logger
  
  @type t() :: %__MODULE__{
    full_path: binary(),
    parts: list(MatchRoutePart.t())
  }
  defstruct [
    full_path: nil, 
    parts: []
  ]

  def new(path) do
    map = %__MODULE__{ full_path: path, parts: [] }    
    split_path = String.split path, "/", trim: true
    parts = Enum.reduce(split_path, [], fn part, acc_parts -> 
      part_struct = MatchRoutePart.new String.starts_with?(part, ":"), Enum.count(acc_parts) + 1, part
      [part_struct | acc_parts]
    end)
    |> Enum.sort_by(&(&1.position))

    %__MODULE__{ map | parts: parts}
  end
  
  def get_parameter_parts(match_route) do
    Enum.filter(match_route.parts, fn elem -> Map.get(elem, :is_parameter) end)
    |> Enum.reduce(Map.new(), fn %{is_parameter: _is_param, position: pos, value: str}, acc -> 
      Map.put(acc, pos, String.to_atom(String.slice(str, 1..-1//1)))
    end)
  end
end

defmodule MatchRoutePart do
  @type t() :: %__MODULE__{is_parameter: boolean(), position: integer(), value: binary()}
  defstruct is_parameter: false, position: nil, value: nil
  
  def new(is_param, pos, str) do
    %MatchRoutePart{ is_parameter: is_param, position: pos, value: str}
  end
end