defmodule Response do
  alias Response.ResponseCode
  alias EndpointBuilder.EndpointResult
  require Logger
      
  @type t() :: %__MODULE__{
    response_code: ResponseCode.t() | nil, 
    body: binary() | nil,
    headers: Headers.t(), 
    finished: boolean()
  }
  defstruct [
    response_code: nil, 
    body: nil, 
    headers: %{},
    finished: false
  ]
  
  @spec new() :: t()
  def new() do
    %__MODULE__{
      headers: Headers.default_response_headers()
    }
  end
  
  @spec apply_endpoint_result(t(), EndpointResult.t()) :: t()
  def apply_endpoint_result(current_response, _endpoint_result = %EndpointResult{response_code: response_code, content: nil, extra_headers: nil}) do
    set_response_code(current_response, response_code)
  end
  
  def apply_endpoint_result(current_response, _endpoint_result = %EndpointResult{response_code: response_code, content: nil, extra_headers: extra_headers}) do
    set_response_code(current_response, response_code)
    |> add_headers(extra_headers)
  end
  
  def apply_endpoint_result(current_response, _endpoint_result = %EndpointResult{response_code: response_code, content: content, extra_headers: nil}) do
    set_response_code(current_response, response_code)
    |> set_body(content)
  end
  
  def apply_endpoint_result(current_response, _endpoint_result = %EndpointResult{response_code: response_code, content: content, extra_headers: extra_headers}) do
    set_response_code(current_response, response_code)
    |> set_body(content)
    |> add_headers(extra_headers)
  end
  
  @spec set_response_code(t(), ResponseCode.t()) :: t()
  def set_response_code(response, response_code) do
    %__MODULE__{response | response_code: response_code}
  end
  
  @spec set_body(t(), binary()) :: t()
  def set_body(current_response, body_content) do
    byte_size = byte_size(body_content)
    content_length_header = Headers.Header.new("Content-Length", "#{byte_size}")
    updated_headers = Headers.add(current_response.headers, content_length_header)
    %__MODULE__{current_response | headers: updated_headers, body: body_content}
  end
  
  @spec add_headers(t(), Headers.t()) :: t()
  def add_headers(response, headers_to_add) do
    merged_headers = Headers.merge(response.headers, headers_to_add)
    %__MODULE__{response | headers: merged_headers}
  end
  
  @spec add_header(t(), Headers.Header.t()) :: t()
  def add_header(response, header_to_add) do
    %__MODULE__{ response | headers: Headers.add(response.headers, header_to_add)}
  end
  
  @spec add_header(t(), binary(), binary()) :: t()
  def add_header(response, key, value) do
    new_header = Headers.Header.new(key, value)
    %__MODULE__{ response | headers: Headers.add(response.headers, new_header)}
  end
  
  @spec add_header(t(), binary(), binary(), list(binary())) :: t()
  def add_header(response, key, value, attributes) do
    new_header = Headers.Header.new(key, value, attributes)
    %__MODULE__{ response | headers: Headers.add(response.headers, new_header)}
  end
  
  @spec format_response(Response.t()) :: {:ok, iodata()} | {:error, reason :: term()}
  def format_response(%__MODULE__{ response_code: response_code, headers: headers, body: nil }) do
    ["HTTP/1.1", " ", ResponseCode.format(response_code), "\r","\n", Headers.format(headers), "\r","\n"]
  end
  
  @spec format_response(Response.t()) :: {:ok, iodata()} | {:error, reason :: term()}
  def format_response(%__MODULE__{ response_code: response_code, headers: headers, body: body }) do
    ["HTTP/1.1", " ", ResponseCode.format(response_code), "\r","\n", Headers.format(headers), "\r","\n", body]
  end
end
