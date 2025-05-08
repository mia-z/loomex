defmodule EndpointBuilder.Actions do
  alias Response.ResponseCode
  defmacro __using__(_opts) do
    quote do
      import EndpointBuilder.Actions
    end
  end
  
  def ok(message) do
    %Response{response_code: ResponseCode.ok, body: message}
  end
  
  def not_found do
    %Response{response_code: ResponseCode.not_found, body: "Not found"}
  end
end