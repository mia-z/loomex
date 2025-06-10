defmodule Loomex.Transport do
  @type t() :: module()
  
  @type receive_state() ::
    {:incomplete, <<>> | binary() | nil} 
    | {:partial, <<>> | binary() | nil}
    | {:complete, <<>> | binary() | nil}
    
  @type request_metadata() :: receive_state()
  
  @type request_body() :: receive_state()
  
  @callback accept(listener_socket :: :socket.socket(), reference(), port :: integer() | nil) ::
    {:select, tag :: :socket.select_tag(), current_ref :: reference()} |
    {:completion, tag :: :socket.completion_tag(), current_ref :: reference()} |
    {:error, reason :: term()}
    
  @callback send_resp(socket :: :ssl.sslsocket() | :socket.socket(), data :: binary() | [binary()]) :: :ok | {:error, reason :: term()}
  
  @callback close_socket(socket :: :ssl.sslsocket() | :socket.socket()) :: :ok | {:error, reason :: term()}
end