defmodule Response do
  alias Response.ResponseCode
  require Logger
      
  @type headers() :: map()
  @type response() :: %__MODULE__{ response_code: ResponseCode.response_code(), headers: headers(), body: nil | binary() }
  defstruct [response_code: nil, body: nil, headers: %{}]

  @spec handle_response(response()) :: {:ok, iodata()} | {:error, :response, term()}
  def handle_response(structured_response = %Response{ headers: headers }) do
    Logger.debug "Starting response handle with data #{inspect structured_response} on pipeline #{inspect self()}"
    structured_response = %Response{ structured_response | headers: Headers.merge(Headers.create_default_response_headers(), headers) }
    formatted_response = handle structured_response
    Logger.debug "Finished response handle #{inspect self()}"
    formatted_response
  end

  @spec handle(response()) :: {:ok, iodata()} | {:error, :response, term()}
  defp handle(structured_response = %Response{}) do
    try do
      formatted_response = format_response structured_response
      {:ok, formatted_response}
    rescue
      err -> 
        Logger.error "Error in handle_response/1\n#{inspect err}"
        {:error, :response, err}
    end
  end
  
  @spec format_response(response()) :: iodata()
  defp format_response(%Response{ response_code: response_code, headers: headers, body: nil }) do
    headers = Headers.add_date_header(headers)
    ["HTTP/1.1", " ", ResponseCode.format(response_code), "\r","\n", Headers.format(headers), "\r","\n"]
  end
  
  @spec format_response(response()) :: iodata()
  defp format_response(%Response{ response_code: response_code, headers: headers, body: body }) do
    ["HTTP/1.1", " ", ResponseCode.format(response_code), "\r","\n", Headers.format(headers), "\r","\n", body]
  end
end
