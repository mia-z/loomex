defmodule Response.ResponseCode do
  @type response_code() ::
    {200, :ok}
      | {201, :created}
      | {202, :accepted}
      | {204, :no_content}
      | {301, :moved_permanently}
      | {302, :found}
      | {303, :see_other}
      | {304, :not_modified}
      | {307, :temporary_redirect}
      | {308, :permanent_redirect}
      | {400, :bad_request}
      | {401, :unauthorized}
      | {403, :forbidden}
      | {404, :not_found}
      | {405, :method_not_allowed}
      | {409, :conflict}
      | {410, :gone}
      | {422, :unprocessable_entity} 
      | {429, :too_many_requests}
      | {500, :internal_server_error}
      | {501, :not_implemented}
      | {502, :bad_gateway}
      | {503, :service_unavailable}
      | {504, :gateway_timeout}
  
  @type status() ::
    :ok
    | :created
    | :accepted
    | :no_content
    | :moved_permanently
    | :found
    | :see_other
    | :not_modified
    | :temporary_redirect
    | :permanent_redirect
    | :bad_request
    | :unauthorized
    | :forbidden
    | :not_found
    | :method_not_allowed
    | :conflict
    | :gone
    | :unprocessable_entity
    | :too_many_requests
    | :internal_server_error
    | :not_implemented
    | :bad_gateway
    | :service_unavailable
    | :gateway_timeout
  
  @type status_code() ::
    200 | 201 | 202 | 204
    | 301 | 302 | 303 | 304 | 307 | 308
    | 400 | 401 | 403 | 404 | 405 | 409 | 410 | 422 | 429
    | 500 | 501 | 502 | 503 | 504
  
  @spec format_reason_phrase(phrase :: atom()) :: binary()
  defp format_reason_phrase(phrase), do:
    Atom.to_string(phrase)
    |> String.split("_")
    |> Enum.map(&String.capitalize(&1))
    |> Enum.join(" ")
    
  @spec format({status_code(), status()}) :: [String.t()]
  def format({c, s}), do: ["#{c}", " ", format_reason_phrase(s)]
  
  @spec ok() :: response_code()
  def ok, do: {200, :ok}

  @spec created() :: response_code()
  def created, do: {201, :created}

  @spec accepted() :: response_code()
  def accepted, do: {202, :accepted}

  @spec no_content() :: response_code()
  def no_content, do: {204, :no_content}

  @spec moved_permanently() :: response_code()
  def moved_permanently, do: {301, :moved_permanently}

  @spec found() :: response_code()
  def found, do: {302, :found}

  @spec see_other() :: response_code()
  def see_other, do: {303, :see_other}

  @spec not_modified() :: response_code()
  def not_modified, do: {304, :not_modified}

  @spec temporary_redirect() :: response_code()
  def temporary_redirect, do: {307, :temporary_redirect}

  @spec permanent_redirect() :: response_code()
  def permanent_redirect, do: {308, :permanent_redirect}

  @spec bad_request() :: response_code()
  def bad_request, do: {400, :bad_request}

  @spec unauthorized() :: response_code()
  def unauthorized, do: {401, :unauthorized}

  @spec forbidden() :: response_code()
  def forbidden, do: {403, :forbidden}

  @spec not_found() :: response_code()
  def not_found, do: {404, :not_found}

  @spec method_not_allowed() :: response_code()
  def method_not_allowed, do: {405, :method_not_allowed}

  @spec conflict() :: response_code()
  def conflict, do: {409, :conflict}

  @spec gone() :: response_code()
  def gone, do: {410, :gone}

  @spec unprocessable_entity() :: response_code()
  def unprocessable_entity, do: {422, :unprocessable_entity}

  @spec too_many_requests() :: response_code()
  def too_many_requests, do: {429, :too_many_requests}

  @spec internal_server_error() :: response_code()
  def internal_server_error, do: {500, :internal_server_error}

  @spec not_implemented() :: response_code()
  def not_implemented, do: {501, :not_implemented}

  @spec bad_gateway() :: response_code()
  def bad_gateway, do: {502, :bad_gateway}

  @spec service_unavailable() :: response_code()
  def service_unavailable, do: {503, :service_unavailable}

  @spec gateway_timeout() :: response_code()
  def gateway_timeout, do: {504, :gateway_timeout}
end