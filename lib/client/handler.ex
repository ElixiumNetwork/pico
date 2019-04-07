defmodule Pico.Client.Handler do
  alias Pico.Protocol.Decoder
  use GenServer
  require IEx

  def start_link(socket, router, handler_name, start_func \\ :generic_start) do
    GenServer.start_link(__MODULE__, [socket, router, handler_name, start_func], name: handler_name)
  end

  def init([socket, router, handler_name, start_func]) do
    Process.send_after(self(), {:immediately_execute, start_func}, 1000)

    {:ok,
      %{
        listen_socket: socket,
        router: router,
        handler_name: handler_name
      }
    }
  end

  @spec read_single_message(pid, binary) :: {String.t, map | nil}
  def read_single_message(socket, secret \\ nil) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, message} -> Decoder.decode(message, secret)
      {:error, :closed} -> Process.exit(self(), :normal)
    end
  end

  def handle_info({:immediately_execute, start_func}, state) do
    apply(state.router, start_func, [state])

    {:noreply, state}
  end

  def handle_info({:tcp, _port, message}, state) do
    # Set to false in case router needs to make multiple comms,
    # this way we dont trigger the handler again.
    :inet.setopts(state.socket, active: false)

    {opname, data} = Decoder.decode(message, state.key, state.iv)

    apply(state.router, :message, [opname, data, state])

    # Set back to true to enable handler to capture messages
    :inet.setopts(state.socket, active: true)
    {:noreply, state}
  end

  def handle_cast(:accept_inbound_connection, state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)

    {key, iv} = authenticate_inbound(socket, state.router)

    state = Map.merge(state, %{socket: socket, key: key, iv: iv})

    :inet.setopts(socket, active: true)

    {:noreply, state}
  end

  @spec authenticate_inbound(pid, atom) :: {binary, binary} | {:error, :closed}
  defp authenticate_inbound(socket, router) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, message} ->
        {opname, data} = Decoder.decode(message)

        <<key::binary-size(32), iv::binary-size(16), _rest::binary>> = apply(router, :message, [opname, data, socket])

        {key, iv}

      {:error, :closed} -> Process.exit(self(), :normal)
    end
  end

end
