defmodule Request.RequestRoute do
  alias Request.RequestRoute, as: RequestRoute
  defstruct full_path: nil, parts: %{}
  
  def new(path) do
    map = %RequestRoute{ full_path: path, parts: %{} }
    
    split_path = String.split path, "/", trim: true
    parts = Enum.reduce split_path, %{}, fn part, acc_parts -> 
      acc_parts = Map.put acc_parts, Enum.count(acc_parts) + 1, part
      acc_parts
    end
    %RequestRoute{ map | parts: parts}
  end
end