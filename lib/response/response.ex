defmodule Response do
  alias Response.ResponseCode
  require Logger
      
  @type headers() :: map()
  @type t() :: %__MODULE__{
    response_code: ResponseCode.response_code(), 
    headers: headers(), 
    body: nil | binary() 
  }
  defstruct [
    response_code: nil, 
    body: nil, 
    headers: %{}
  ]

  @spec handle_response(Response.t(), pid()) :: {:ok, iodata()} | {:error, :response, term()}
  def handle_response(structured_response = %Response{ headers: headers }, _pipeline_context) do
    Logger.debug "Starting response handle with data #{inspect structured_response} on pipeline #{inspect self()}"
    merged_headers = Headers.merge Headers.default_response_headers(), headers
    structured_response = %__MODULE__{ structured_response | headers: merged_headers }
    formatted_response = handle structured_response
    Logger.debug "Finished response handle #{inspect self()}"
    formatted_response
  end

  @spec handle(Response.t()) :: {:ok, iodata()} | {:error, :response, term()}
  defp handle(structured_response = %__MODULE__{}) do
    formatted_response = format_response structured_response
    {:ok, formatted_response}
  rescue
    err -> 
      Logger.error "Error in handle_response/1\n#{inspect err}"
      {:error, :response, err}
  end
  
  @spec format_response(Response.t()) :: iodata()
  defp format_response(%__MODULE__{ response_code: response_code, headers: headers, body: nil }) do
    ["HTTP/1.1", " ", ResponseCode.format(response_code), "\r","\n", Headers.format(headers), "\r","\n"]
  end
  
  @spec format_response(Response.t()) :: iodata()
  defp format_response(%__MODULE__{ response_code: response_code, headers: headers, body: body }) do
    ["HTTP/1.1", " ", ResponseCode.format(response_code), "\r","\n", Headers.format(headers), "\r","\n", body]
  end
end
