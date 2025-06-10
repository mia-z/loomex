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

  @doc """
    Builds a handler for the provided route and method

    If no method is provided, GET will be used

    While the success typing for an endpoint involves returning a `Request` struct,
    you should use the provided helpers in `EndpointBuilder.Actions`
    """
  defmacro endpoint(method \\ :GET, path, do: block) do
    normalized_path_part = String.replace(path, ~r/[^A-Za-z0-9_]/, "_")
    handler_module_name = String.to_atom("handler_module_#{method}_#{normalized_path_part}")

    quote do
      defmodule unquote(handler_module_name) do
        @spec __handler__(req :: Request.t()) :: Response.t()
        def __handler__(req) do
          import EndpointBuilder.Actions
          var!(req, nil) = req
          _ = var!(req)

          var!(query, nil) = req.query_params
          _ = var!(query)

          var!(route, nil) = req.route_params
          _ = var!(route)

          var!(form, nil) = req.body.data
          _ = var!(form)
          
          var!(body, nil) = req.body.data
          _ = var!(body)
          
          var!(json, nil) = req.body.data
          _ = var!(json)
          
          unquote(block)
        end
      end
      @endpoints_coll [{unquote(path), unquote(method), &unquote(handler_module_name).__handler__/1} | @endpoints_coll]
    end
  end
  
  defmacro get(path, do: block) do
    quote do
      endpoint(:GET, unquote(path), do: unquote(block))
    end
  end
  
  defmacro post(path, do: block) do
    quote do
      endpoint(:POST, unquote(path), do: unquote(block))
    end
  end
  
  defmacro put(path, do: block) do
    quote do
      endpoint(:PUT, unquote(path), do: unquote(block))
    end
  end
  
  defmacro patch(path, do: block) do
    quote do
      endpoint(:PATCH, unquote(path), do: unquote(block))
    end
  end
  
  defmacro delete(path, do: block) do
    quote do
      endpoint(:DELETE, unquote(path), do: unquote(block))
    end
  end
  
  
end
