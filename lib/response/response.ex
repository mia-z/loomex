defmodule Response do
  alias Response.ResponseCode
  require Logger
    
  @type headers() :: %{}
  @type response() :: %Response{ response_code: ResponseCode.response_code(), headers: headers(), body: term() }
  defstruct [:response_code, :body, headers: []]

  @spec handle_response(response()) :: {:ok, String.t()} | {:error, :response, term()}
  def handle_response(structured_response) do
    Logger.debug "Starting response handle with data #{inspect structured_response} on pipeline #{inspect self()}"
    formatted_response = handle structured_response
    Logger.debug "Finished response handle #{inspect self()}"
    formatted_response
  end

  @spec handle(response()) :: {:ok, String.t()} | {:error, :response, term()}
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
  
  defp format_response(%Response{ response_code: response_code, headers: headers }) do
    "HTTP/1.1 #{ResponseCode.format response_code}" <>
    Headers.format(headers)
  end
  
  defp format_response(%Response{ response_code: response_code, headers: headers, body: body }) do
    "HTTP/1.1 #{ResponseCode.format response_code}" <>
    Headers.format(headers) <>
    body
  end
end
