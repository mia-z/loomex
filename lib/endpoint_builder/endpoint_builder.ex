defmodule EndpointBuilder do  
  defmacro __using__(_) do
    quote do
      @before_compile EndpointBuilder
      @endpoints_coll []
      
      defmodule unquote(Module.concat(Marker.EndpointBuilder.RouteDefinitions, __CALLER__.module)), do: :ok
          
      import EndpointBuilder
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do
      def __routes__(), do: @endpoints_coll
    end
  end
  
  defmacro endpoint(method \\ :GET, path, do: block) do
    normalized_path_part = String.replace(path, ~r/[^A-Za-z0-9_]/, "_")
    handler_module_name = String.to_atom("handler_module_#{method}_#{normalized_path_part}")
    
    quote do
      defmodule unquote(handler_module_name) do
        defp get_req(req), do: req
        defp get_query(query), do: query
        def __handler__(var!(req), var!(query)) do
          import EndpointBuilder.Actions
          req = get_req(var!(req))
          query = get_query(var!(query))
          unquote(block)
        end
      end
      @endpoints_coll [{unquote(path), unquote(method), &unquote(handler_module_name).__handler__/2} | @endpoints_coll]
    end
  end
end
