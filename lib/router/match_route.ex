defmodule Router.MatchRoute do
  alias Router.MatchRoute, as: MatchRoute
  defstruct full_path: nil, parts: %{}

  def new(path) do
    map = %MatchRoute{ full_path: path, parts: [] }    
    split_path = String.split path, "/", trim: true
    parts = Enum.reduce(split_path, [], fn part, acc_parts -> 
      part_struct = MatchRoutePart.new String.starts_with?(part, ":"), Enum.count(acc_parts) + 1, part
      [part_struct | acc_parts]
    end)
    |> Enum.sort_by(&(&1.position))

    %MatchRoute{ map | parts: parts}
  end
end

defmodule MatchRoutePart do
  defstruct is_parameter: false, position: nil, value: nil
  
  def new(is_param, pos, str) do
    %MatchRoutePart{ is_parameter: is_param, position: pos, value: str}
  end
end