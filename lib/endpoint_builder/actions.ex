defmodule EndpointBuilder.Actions do
  alias Response.ResponseCode
  
  defp new_res(rc), do: 
    %Response{response_code: rc}
 
  defp new_res(rc, b), do: 
    %Response{response_code: rc, body: b}
  
  def ok(message), do:
    new_res(ResponseCode.ok, message)
  
  def ok, do:
    new_res(ResponseCode.ok)
  
  def not_found, do:
    new_res(ResponseCode.not_found)
  
  def bad_request, do:
    new_res(ResponseCode.bad_request)
end