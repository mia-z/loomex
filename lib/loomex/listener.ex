defmodule Loomex.Listener do
  require Logger

  alias Loomex.SSLHelper
  alias Loomex.Pipeline

  use GenServer

  def start_link(args, opts \\ []) do
    Logger.info("Starting listener\nargs: #{inspect(args)}\nopts: #{inspect(opts)}")
    port = Keyword.get args, :port, 4044
    mode = Keyword.get args, :mode, :tcp
    case {mode, port} do
      {:tcp, port} -> GenServer.start_link(__MODULE__, {:tcp, port}, opts)
      {:ssl, port} -> GenServer.start_link(__MODULE__, {:ssl, port}, opts)
      _ -> raise "Invalid options, aborting"
    end
  end

  @impl true
  def init({:tcp, port}) do
    Logger.debug("Init listener\nmode: #{:tcp}\nport: #{inspect(port)}")

    case :gen_tcp.listen(port, [:binary, packet: :raw, active: :once, reuseaddr: true]) do
      {:ok, listen_socket} ->
        Logger.info("Listener started on port #{port} in active mode")
        {:ok, %{listen_socket: listen_socket}, {:continue, :serve_tcp}}

      {:error, reason} ->
        Logger.error("Failed to start listener on port #{port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def init({:ssl, port}) do
    Logger.debug("Init listener\nmode: #{:ssl}\nport: #{inspect(port)}")
    cert_map = SSLHelper.create()

    case :ssl.listen(port, [
           :binary,
           packet: :raw,
           active: false,
           reuseaddr: true,
           certs_keys: [cert_map]
         ]) do
      {:ok, listen_socket} ->
        Logger.info("Listener started on port #{port}, in active mode with ssl")
        {:ok, %{listen_socket: listen_socket}, {:continue, :serve_ssl}}

      {:error, reason} ->
        Logger.error("Failed to start listener on port #{port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:serve_tcp, state = %{listen_socket: listen_socket}) do
    :inet.setopts(listen_socket, active: 2)

    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        Logger.debug("Got request, dispatching..")
        Pipeline.dispatch({:tcp_socket, client_socket})

      {:error, :closed} ->
        Logger.info("Listener stopped")
    end

    {:noreply, state, {:continue, :serve_tcp}}
  end

  @impl true
  def handle_continue(:serve_ssl, state = %{listen_socket: listen_socket}) do
    case :ssl.transport_accept(listen_socket) do
      {:ok, transport_socket} ->
        try do
          case :ssl.handshake(transport_socket, 5000) do
            {:ok, final_ssl_socket} ->
              Logger.debug("Got request, dispatching..")
              Pipeline.dispatch({:ssl_socket, final_ssl_socket})

            {:error, reason} ->
              Logger.error("SSL Handshake failed (returned error): #{inspect(reason)}")
              :ssl.close(transport_socket)
          end
        rescue
          exception ->
            stacktrace = __STACKTRACE__

            Logger.error("""
              SSL Handshake RESCUED EXCEPTION! Socket: #{inspect(transport_socket)}
              Exception: #{inspect(exception)}
              Stacktrace: #{inspect(stacktrace)}
            """)
        end
    end

    {:noreply, state, {:continue, :serve_ssl}}
  end
end
