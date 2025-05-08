defmodule EndpointBuilder.Registry do
  require Logger
  
  def get_endpoint_builder_route_definitions, do:
    :application.loaded_applications
    |> collect_modules_from_applications
    |> collect_route_definitions
    |> Enum.flat_map(fn m -> m end)
  
  defp has_endpoint_builder_module?(modules), 
    do: Enum.any?(modules, fn module_key -> String.starts_with?(to_string(module_key), "Elixir.Marker.EndpointBuilder.RouteDefinitions.") end)
  
  defp collect_modules_from_applications(applications), do:
    Enum.reduce(applications, [], fn {app, _desc, _loc}, acc ->
      {:ok, modules} = :application.get_key(app, :modules)
      if has_endpoint_builder_module?(modules), 
        do: collect_modules_with_endpoint_builder(modules, acc),
        else: acc
    end)
  
  defp collect_modules_with_endpoint_builder(modules, acc), do:
    Enum.reduce(modules, acc, fn mod, acc -> 
      try do
        Logger.debug "Scanning module #{inspect mod} since it's app contains EndpointBuilder markers"
        case Keyword.get(mod.__info__(:functions), :__routes__) do
          nil -> acc
          0 -> [mod | acc] 
        end
      rescue
        _ -> acc  
      end
    end)
  
  defp collect_route_definitions(endpoint_builder_modules), do:
    Enum.reduce(endpoint_builder_modules, [], fn eb_module, acc ->
      [apply(eb_module, :__routes__, []) | acc]
    end)
end