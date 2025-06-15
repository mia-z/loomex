defmodule Headers do
  alias Headers.Header
  require Logger
  
  @type t() :: %{binary() => Header.t()}
  
  @spec parse(String.t()) :: t()
  def parse(headers) when is_binary(headers) do
    String.split(headers, "\r\n") 
    |> parse
  end
  
  @spec parse(list(String.t())) :: t()
  def parse(header_lines) when is_list(header_lines) do
    Enum.reduce(header_lines, Map.new(), fn header_line, acc ->
      parsed_header = Header.new(header_line)
      Map.put(acc, parsed_header.key, parsed_header)
    end)
  end
  
  @spec merge(t(), t()) :: t()
  def merge(headers1, headers2) do
    Map.merge(headers1, headers2)
  end
    
  @spec add(t(), Header.t()) :: t()
  def add(headers, header_to_add) do
    Map.put(headers, header_to_add.key, header_to_add)
  end
  
  @spec add(t(), binary(), binary()) :: t()
  def add(headers, key, value) do
    Map.put(headers, key, Header.new(key, value))
  end
  
  @doc "Removes a header with a given header name from the header collection and returns the updated collection"
  @spec remove(t(), binary()) :: t()
  def remove(headers, key) do
    Map.delete(headers, key)
  end
  
  @doc "Get header from header collection, returns :none if it doesnt exist"
  @spec get(t(), binary()) :: Header.t() | :none
  def get(headers, header_key) do
    Map.get(headers, header_key, :none)
  end
  
  @doc "Checks if a header exists in the collection with the given key"
  @spec exists?(t(), binary()) :: boolean()
  def exists?(headers, header_key) do
    Map.has_key?(headers, header_key)
  end
  
  @doc "Prepares headers for outgoing iodata"
  @spec format(t()) :: iodata()
  def format(headers) do
    Enum.filter(headers, fn {_header_name, header_struct} -> header_struct.malformed == false end)
    |> Enum.map(fn {_header_name, header_struct} -> header_struct end)
    |> Enum.reduce([], fn header, acc -> [Header.format(header) | acc] end)
  end

  @spec default_response_headers() :: t()
  def default_response_headers() do
    %{
      "Date" => Header.date(),
      "Server" => Header.new("Server", "Loomex"),
      "Connection" => Header.new("Connection", "Keep-Alive")
    }
  end
  
  @doc "Gets the value of the Content-Length headerl it doesn't exist returns 0"
  @spec content_length(t()) :: non_neg_integer()
  def content_length(headers) do
    if Headers.exists?(headers,"Content-Length"),
      do: String.to_integer(Headers.get(headers, "Content-Length").value),
      else: 0
  end
  
  defmodule Header do
    @type t() :: %__MODULE__{
      key: binary(),
      value: binary() | integer(),
      attributes: %{binary() => binary()} | nil,
      malformed: boolean()
    }
    defstruct [
      key: nil,
      value: nil,
      attributes: nil,
      malformed: false
    ]
    
    @doc "Creates a new Header.t() struct from a header key, value and a attribute 'key=value' list"
    @spec new(header_key :: binary(), header_value :: binary(), attributes :: list(binary())) :: t()
    def new(header_key, header_value, attributes) when is_list(attributes) do
      header_attributes = parse_header_attributes(attributes)
      %__MODULE__{key: header_key, value: header_value, attributes: header_attributes}
    end
    
    @doc "Creates a new Header.t() struct from a header key and value"
    @spec new(header_key :: binary(), header_value :: binary()) :: t()
    def new(header_key, header_value) do 
      %__MODULE__{key: header_key, value: header_value, attributes: nil}
    end

    @doc "Creates a new Header.t() struct from a raw 'Header-Key: header-value' string"
    @spec new(binary()) :: t()
    def new(key_and_value_string) when is_binary(key_and_value_string) do 
      parse(key_and_value_string)
    end
    
    @doc "Formats header into iodata"
    @spec format(t()) :: iodata()
    def format(%__MODULE__{key: key, value: value, attributes: attrs}) do
      case attrs do
        nil ->
          [key, ":", " ", value, "\r", "\n"]
        _ ->
          attr_string = Enum.reduce(attrs, [], fn {k, v}, acc -> 
            case v do
              true ->
                [k | acc]
              ^v ->
                ["#{k}=#{v}" | acc]
            end
          end)
          |> Enum.join("; ")
          [key, ":", " ", value, "; ", attr_string, "\r", "\n"]
      end      
    end
    
    @doc "Checks for the existence of an attribute given its key"
    @spec has_attribute?(t(), binary()) :: boolean()
    def has_attribute?(_header = %__MODULE__{attributes: attributes}, attribute_key) do
      Map.has_key? attributes, attribute_key
    end
    
    @doc """
    Returns the value of an attribute given its key
    
    If the attribute is an attribute with no explicit value, returns the key instead
    """
    @spec get_attribute(t(), binary()) :: binary()
    def get_attribute(_header = %__MODULE__{attributes: attributes}, attribute_key) do
      case Map.get attributes, attribute_key do
        true ->
          attribute_key
        nil ->
          nil
        value ->
          value
      end
    end
    
    @doc """
    Creates Date header with current time
    
    Example: Date: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
    """
    @spec date() :: t()
    def date do
      formatted_dt = DateTime.now("Etc/UTC")
      |> elem(1)
      |> Calendar.strftime("%a, %d %m %Y %H:%M:%S GMT")
      %__MODULE__{key: "Date", value: formatted_dt}
    end
    
    defp parse(header_kvp_string) do
      case String.split header_kvp_string, ": ", parts: 2 do
        [key, value_and_or_attributes] ->
          case String.split value_and_or_attributes, "; ", trim: true do
            [^value_and_or_attributes = value] ->
              %__MODULE__{key: key, value: value}
            [value | attributes_after_value] ->
              attributes_map = parse_header_attributes(attributes_after_value)
              %__MODULE__{key: key, value: value, attributes: attributes_map}
            _ ->
              %__MODULE__{key: key, value: <<>>, malformed: true}
          end
        _ ->
          %__MODULE__{key: header_kvp_string, value: <<>>, malformed: true}
      end
    end
    
    defp parse_header_attributes(attribute_pair_list) do
      Logger.info "Got header attributes: #{inspect attribute_pair_list}"
      Enum.reduce(attribute_pair_list, Map.new(), fn kvp, acc -> 
        case String.split kvp, "=", parts: 2, trim: true do
          [single_value] ->
            Map.put acc, single_value, true
          [key, value] ->
            Map.put acc, key, value
          _ -> acc
        end
      end)
    end
  end
end