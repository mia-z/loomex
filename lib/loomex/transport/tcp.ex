defmodule Loomex.Transport.Tcp do
  require Logger
    
  @behaviour Loomex.Transport
  
  @impl true
  def accept(listener_socket, reference, _port) do
    Logger.debug "Performing accept.", socket: listener_socket, socket_ref: reference        
    case :socket.accept listener_socket, reference do
      {:ok, client_socket} ->
        Logger.debug "Successfully accepted client, starting receive.", subfunc: "accept:ok", socket: listener_socket, socket_ref: reference
        Loomex.Transport.Tcp.Receiver.dispatch client_socket
        accept listener_socket, make_ref(), nil
      {:select, {:select_info, tag, ^reference}} ->
        Logger.debug ":socket.accept returned :select, with tag #{inspect tag}\nCurrent transport finished, waiting..", subfunc: "accept:select", socket: listener_socket, socket_ref: reference
        {:select, tag, reference}
      {:completion, {:completion_info, tag, ^reference}} ->
        Logger.warning ":socket.accept (after :select event) returned :completion\nCurrent transport finished, waiting..", subfunc: "accept:completion", socket: listener_socket, socket_ref: reference
        Logger.warning "Not implemented completion events"
        {:completion, tag, reference}
      {:error, reason} ->
        Logger.error "Error during accept for ref", subfunc: "accept:error", socket: listener_socket, socket_ref: reference, reason: reason
        {:error, reason}
    end
  end
  
  @impl true
  def send_resp(socket, data) do
    :socket.send socket, data
  end
  
  @impl true
  def close_socket(socket) do
    :socket.close socket  
  end
  
  def sync_recv(socket, initial_data, body_length) do
    case :socket.recv socket do
      {:ok, data} ->
        Logger.debug "Got data in blocking receive: #{inspect data}"
      {:error, {reason, data}} ->
        Logger.error "Got error with data in blocking receive: #{inspect data}", reason: reason
      {:error, reason} ->
        Logger.error "Got error in blocking receive", reason: reason
    end
  end
  
  defp recv_loop(socket, data) do
  end
end