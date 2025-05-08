defmodule Loomex.Transport.Tls do
  alias Loomex.SSLHelper
  require Logger
  
  @behaviour Loomex.Transport
  
  @impl true
  def accept(listener_socket, reference, port) do
    Logger.debug "Performing accept.", socket: listener_socket, socket_ref: reference
    case :socket.accept listener_socket, reference do
      {:ok, client_socket} ->
        Logger.debug "Successfully accepted client, performing handshake.", subfunc: "accept:ok", socket: listener_socket, socket_ref: reference
        with {:found, {^port, cert_map}} <- SSLHelper.get_certs(port), 
          {:ok, ssl_client_socket} <- :ssl.handshake(client_socket, [certs_keys: [cert_map]], 5000) do
            Logger.debug "TLS Handshake success.", subfunc: "handshake:ok", socket: listener_socket, socket_ref: reference
            Loomex.Transport.Tls.Receiver.dispatch ssl_client_socket
        else
          :not_found ->
            Logger.error "Failed fetch SSL certificates", subfunc: "get_certs:not_found", socket: listener_socket, socket_ref: reference
            :socket.close client_socket
          {:error, reason} ->
            Logger.error "Failed TLS handshake", subfunc: "handshake:error", reason: reason, socket: listener_socket, socket_ref: reference
            :socket.close client_socket
        end
        accept listener_socket, make_ref(), port
      {:select, {:select_info, tag, ^reference}} ->
        Logger.debug ":socket.accept (after :select event) returned :select again, with tag #{inspect tag}", subfunc: "accept:select", socket: listener_socket, socket_ref: reference
        {:select, tag, reference}
      {:completion, {:completion_info, tag, ^reference}} ->
        Logger.debug ":socket.accept (after :select event) returned :completion with tag #{inspect tag}", subfunc: "accept:completion", socket: listener_socket, socket_ref: reference
        Logger.warning "Not implemented completion events"
        {:completion, tag, reference}
      {:error, reason} ->
        Logger.error "Error during accept for ref #{inspect reference}", subfunc: "accept:error", reason: reason, socket: listener_socket, socket_ref: reference
        {:error, reason}
    end
  end
  
  @impl true
  def send_resp(socket, data) do
    :ssl.send socket, data
  end
  
  @impl true
  def close_socket(socket) do
    :ssl.close socket  
  end
end