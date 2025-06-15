defmodule EndpointBuilder.EndpointResult do
  alias Response.ResponseCode
  
  @type t() :: %__MODULE__{
    response_code: ResponseCode.t(),
    content: nil | binary(),
    extra_headers: Headers.t()
  }
  defstruct [
    response_code: nil,
    content: nil,
    extra_headers: %{}
  ] 

  @spec endpoint_result(response_code :: ResponseCode.t()) :: %__MODULE__{ response_code: {integer(), atom()}, content: nil, extra_headers: %{}}
  def endpoint_result(response_code) do
    %__MODULE__{
      response_code: response_code
    }
  end
  
  @spec endpoint_result(response_code :: ResponseCode.t(), body :: binary()) :: t()
  def endpoint_result(response_code, body) when is_binary(body) do
    %__MODULE__{
      response_code: response_code,
      content: body
    }
  end
  
  @spec endpoint_result(response_code :: ResponseCode.t(), Headers.t()) :: t()
  def endpoint_result(response_code, extra_headers) when is_map(extra_headers) do
    %__MODULE__{
      response_code: response_code,
      extra_headers: extra_headers
    }
  end
  
  @spec endpoint_result(response_code :: ResponseCode.t(), body :: binary(), extra_headers :: Headers.t()) :: t()
  def endpoint_result(response_code, body, extra_headers) do
    %__MODULE__{
      response_code: response_code,
      content: body,
      extra_headers: extra_headers
    }
  end
  
  @spec ok(content :: binary()) :: t()
  def ok(content) do
    %__MODULE__{
      response_code: ResponseCode.ok,
      content: content
    }
  end
  
  @spec ok() :: t()
  def ok do
    %__MODULE__{
      response_code: ResponseCode.ok,
    }
  end
  
  @spec json_result(json_body :: map()) :: t()
  def json_result(json_body) do
    encoded = JSON.encode!(json_body)
    %__MODULE__{
      response_code: ResponseCode.ok,
      content: encoded,
      extra_headers: %{"Content-Type" => Headers.Header.new("Content-Type", "application/json")}
    }
  end
  
  @spec text_result(text_body :: binary()) :: t()
  def text_result(text_body) when is_binary text_body do
    %__MODULE__{
      response_code: ResponseCode.ok,
      content: text_body,
      extra_headers: %{"Content-Type" => Headers.Header.new("Content-Type", "text/plain")}
    }
  end
  
  @spec not_found() :: %__MODULE__{response_code: {404, :not_found}}
  def not_found do
    %__MODULE__{
      response_code: ResponseCode.not_found
    }
  end
  
  @spec bad_request() :: %__MODULE__{response_code: {400, :bad_request}}
  def bad_request do
    %__MODULE__{
      response_code: ResponseCode.bad_request,
    }  
  end
end