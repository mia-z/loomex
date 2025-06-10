defmodule Loomex.Logger do
  require Logger

  def log(level, message, timestamp, metadata) do
    case level do
      :info -> print_info(level, message, timestamp, metadata)
      :debug -> if metadata[:application] == :loomex, 
        do: print_debug(level, message, timestamp, metadata),
        else: print_default(level, message, timestamp, metadata)
      _ -> print_default(level, message, timestamp, metadata)
    end
    
  end
  
  defp print_info(_level, message, _timestamp, _metadata) do
    ["[INFO]", "\n", message, "\n"]
  end
  
  defp print_debug(_level, message, _timestamp, metadata) do
    clean_mod_name = String.replace to_string(Keyword.get(metadata, :module)), "Elixir.", <<>>
    clean_fun_name = case Keyword.get(metadata, :function, :none) do
      :none -> "?"
      function_data when is_list(function_data) -> List.first(Keyword.get(metadata, :function), "?")
      _ -> "?"
    end
    
    base = ["----------", "\n"]
    base = [message, "\n" | base]
  
    base = if Keyword.has_key?(metadata, :reason),
      do: ["[Reason]", inspect(Keyword.get(metadata, :reason)), "\n" | base],
      else: base

    
    base = if Keyword.has_key?(metadata, :socket_ref), 
      do: ["[Socket Ref: ", inspect(Keyword.get(metadata, :socket_ref)), "]", "\n" | base],
      else: base

    base = if Keyword.has_key?(metadata, :socket), 
      do: ["[", "Socket: ", inspect(Keyword.get(metadata, :socket)), "]", "\n" | base],
      else: base
      
    base = if Keyword.has_key?(metadata, :subfunc),
      do: ["[", clean_mod_name, ":", clean_fun_name, ":", Keyword.get(metadata, :subfunc), "]", "\n" | base],
      else: ["[", clean_mod_name, ":", clean_fun_name, "]", "\n" | base]

    ["[DEBUG]", "\n" | base]
  end
  
  defp print_default(level, message, _timestamp, _metadata) do
    ["[", String.upcase(Atom.to_string(level)), "]", "\n", message, "\n"]
  end
end