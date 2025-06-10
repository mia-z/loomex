defmodule Request.Body do
  alias Headers.Header
  require Logger
  
  @type transport_layer() :: {:ssl.socket(), Loomex.Transport.Tls} | {:socket.socket(), Loomex.Transport.Tcp}
  @type body_state() :: :ready | :empty | :needs_continue | :partial | :incomplete | :error
  @type content_media_type() :: :multipart | :application | :image | :text | :audio | :message | :video | :x_token
  @type content_media_subtype() :: 
    :plain | :richtext | :html | :xml | # text/* subtypes
    :mixed | :alternative | :parallel | :digest | :form_data | #multipart/* subtypes
    :json | :xml | :x_www_form_urlencoded | :octet_stream #application/* subtypes
  @type body_type() :: {content_media_type(), content_media_subtype()} | nil
  
  @type t() :: 
    %__MODULE__{ state: :empty, data:  nil, type: :none } |
    %__MODULE__{ state: :ready, data: term(), type: :not_fully_implemented } |
    %__MODULE__{ state: :error, data: term(), type: :json } |
    %__MODULE__{ state: body_state(), data: binary() | nil, type: :raw } |
    %__MODULE__{ state: body_state(), data: map(), type: :json | :form_data }

  defstruct [
    state: :incomplete,
    data: nil,
    type: :none
  ]
  
  @spec prepare_initial(initial_body_state :: Loomex.Transport.receive_state(), request :: Request.t()) :: t()
  def prepare_initial(initial_body_state, _request = %Request{headers: headers}) do
    cond do
      Headers.content_length(headers) == 0 ->
        %__MODULE__{
          state: :empty
        }
      Headers.exists?(headers, "Content-Type") ->
        handle_content_type(initial_body_state, headers)
      Headers.exists?(headers, "Content-Length") ->
        handle_body_with_only_content_length(initial_body_state, headers)
      true -> #Catch all
        %__MODULE__{
          state: :empty
        }
    end
  end 
  
  defp handle_body_with_only_content_length(initial_body_state, headers) do
    {_receive_status, current_body} = initial_body_state
    body_length = String.to_integer(Map.get(headers, "Content-Length"))
    if body_length == byte_size(current_body) do
      %__MODULE__{
        state: :ready,
        data: current_body,
        type: :raw
      }
    else
      Logger.error "Body length mismatch, declared length #{body_length}, got length: #{String.length(current_body)}"
      %__MODULE__{
        state: :partial,
        data: current_body,
        type: :raw
      }
    end
  end
  
  defp handle_content_type(initial_body_state, headers) do
    %Header{value: value, attributes: attributes} = Headers.get(headers, "Content-Type")
    Logger.info "Got a Content-Type header, media type: #{inspect value}, attributes: #{inspect attributes}"
    Logger.info inspect headers
    handle_content_type(value, attributes, initial_body_state, headers)
  end
  
  defp handle_content_type("application/" <> subtype, header_attributes, initial_body_state, headers) do
    Logger.info "#{inspect subtype}"
    case subtype do
      "x-www-form-urlencoded" ->
        {_receive_status, current_body} = initial_body_state
        decoded = URI.decode_www_form(current_body) |> URI.decode_query()
        %__MODULE__{
          state: :ready,
          data: decoded,
          type: :form_data
        }
      "json" ->
        {_receive_status, current_body} = initial_body_state
        case JSON.decode(current_body) do
          {:ok, decoded_json} ->
            %__MODULE__{
              state: :ready,
              data: decoded_json,
              type: :json
            }
          {:error, reason} -> 
            Logger.error "Couldnt decode JSON body", reason: reason
            %__MODULE__{
              state: :error,
              data: inspect(reason),
              type: :json
            }
        end
      _ ->
        {_receive_status, current_body} = initial_body_state
        %__MODULE__{
          state: :ready,
          data: current_body,
          type: :not_fully_implemented
        }
    end
  end
  
  defp handle_content_type("multipart/form-data", header_attributes = %{}, initial_body_state, headers) do
    {_receive_status, current_body} = initial_body_state
    boundary_key = Map.get(header_attributes, "boundary")

    Logger.info "Content type boundary key: #{inspect boundary_key}"

    get_multipart_sections(boundary_key, current_body)
  end
  
  defp get_multipart_sections(boundary_key, form_data) do
    Logger.info "Got splitting form data: #{inspect form_data}"
    sections = String.split(form_data, ["--" <> boundary_key <> "\r\n", "\r\n--" <> boundary_key <> "\r\n", "\r\n--" <> boundary_key <> "--" <> "\r\n"], trim: true)
    
    Logger.info "Got boundary parts: #{inspect sections}"
    Logger.info "LAST PART: #{inspect List.last(sections)}"
  end
end