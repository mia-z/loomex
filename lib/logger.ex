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
    ["[INFO]", ~c"\n", message, ~c"\n"]
  end
  
  defp print_debug(_level, message, _timestamp, metadata) do
    clean_mod_name = String.replace to_string(Keyword.get(metadata, :module)), "Elixir.", <<>>
    clean_fun_name = case Keyword.get(metadata, :function, :none) do
      :none -> ~c"?"
      function_data when is_list(function_data) -> List.first(Keyword.get(metadata, :function), "?")
      _ -> ~c"?"
    end
    
    base = ["----------", ~c"\n"]
    base = [message, ~c"\n" | base]
  
    base = if Keyword.has_key?(metadata, :reason),
      do: ["[", ~c"Reason", "]", inspect(Keyword.get(metadata, :reason)), "\n" | base],
      else: base

    
    base = if Keyword.has_key?(metadata, :socket_ref), 
      do: ["[", "Socket Ref: ", inspect(Keyword.get(metadata, :socket_ref)), "]", "\n" | base],
      else: base

    base = if Keyword.has_key?(metadata, :socket), 
      do: ["[", "Socket: ", inspect(Keyword.get(metadata, :socket)), "]", "\n" | base],
      else: base
      
    base = if Keyword.has_key?(metadata, :subfunc),
      do: ["[", to_charlist(clean_mod_name), ":", to_charlist(clean_fun_name), ":", to_charlist(Keyword.get(metadata, :subfunc)), "]", "\n" | base],
      else: ["[", to_charlist(clean_mod_name), ":", to_charlist(clean_fun_name), "]", "\n" | base]

    ["[DEBUG]", "\n" | base]
  end
  
  defp print_default(level, message, _timestamp, _metadata) do
    ["[", String.upcase(Atom.to_string(level)), "]", ~c"\n", message, ~c"\n"]
  end
end