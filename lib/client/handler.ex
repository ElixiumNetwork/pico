defmodule Pico.Client.Handler do
  alias Pico.Protocol.Decoder
  alias Pico.Client.SharedState
  use GenServer
  require Logger

  @moduledoc false

  @spec start_link(pid, atom, atom, integer, list(tuple)) :: {:ok, pid}
  def start_link(socket, router, handler_name, handler_number, peers) do
    GenServer.start_link(__MODULE__, [socket, router, handler_name, handler_number, peers], name: handler_name)
  end

  @spec init(list) :: {:ok, map}
  def init([socket, router, handler_name, handler_number, peers]) do
    Process.flag(:trap_exit, true)
    Process.send_after(self(), :start_connection, 1000)

    {:ok,
      %{
        listen_socket: socket,
        router: router,
        handler_name: handler_name,
        handler_number: handler_number,
        peers: peers
      }
    }
  end

  @spec accept_inbound_connection(pid) :: none
  def accept_inbound_connection(handler) do
    GenServer.cast(handler, :accept_inbound_connection)
  end

  @spec attempt_outbound_connection(pid, charlist, integer) :: none
  def attempt_outbound_connection(handler, ip, port \\ 31013) do
    GenServer.cast(handler, {:attempt_outbound_connection, ip, port})
  end

  @spec message_peer(pid, String.t, map) :: none
  def message_peer(handler, opname, data) do
    GenServer.cast(handler, {:message_peer, opname, data})
  end

  @spec read_single_message(pid, binary) :: {String.t, map | nil}
  def read_single_message(socket, key \\ nil, iv \\ nil) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, message} -> Decoder.decode(message, key, iv)
      {:error, :closed} -> Process.exit(self(), :normal)
    end
  end

  def handle_info({:tcp, _port, message}, state) do
    # Set to false in case router needs to make multiple comms,
    # this way we dont trigger the handler again.
    :inet.setopts(state.socket, active: false)

    {opname, data} = Decoder.decode(message, state.key, state.iv)

    apply(state.router, :message, [opname, data, {state.socket, state.key, state.iv}, state])

    # Set back to true to enable handler to capture messages
    :inet.setopts(state.socket, active: true)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
    SharedState.remove_connection(state.handler_name)
    abort_connection("Lost connection from peer: #{state.peername}. TCP closed")

    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, :normal}, state) do
    SharedState.remove_connection(state.handler_name)

    exit(:normal)
    {:noreply, state}
  end

  def handle_info(:start_connection, state) do
    case state.peers do
      [] ->
        Logger.warn("#{state.handler_name}: No known peers! Accepting inbound connections instead.")
        GenServer.cast(state.handler_name, :accept_inbound_connection)

      peers ->
        if length(peers) >= state.handler_number do
          {ip, port} = Enum.at(peers, state.handler_number - 1)

          existing_connections = Enum.map(Pico.connected_handlers(), fn {_, ip} -> ip end)

          if to_string(ip) in existing_connections do
            Logger.info("#{state.handler_name}: Connection already exists to #{ip}. Starting listener instead")
            GenServer.cast(state.handler_name, :accept_inbound_connection)
          else
            GenServer.cast(state.handler_name, {:attempt_outbound_connection, ip, port})
          end
        else
          Logger.info("#{state.handler_name}: No available peers. Starting listener instead.")
          GenServer.cast(state.handler_name, :accept_inbound_connection)
        end
    end

    {:noreply, state}
  end

  def handle_cast(:accept_inbound_connection, state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)

    peername = get_peername(socket)
    existing_connection = Enum.find(Pico.connected_handlers(), fn {_, ip} -> ip == peername end)

    if existing_connection do
      {handler, ip} = existing_connection
      abort_connection("Aborting connection attempt to #{ip}, #{handler} is already connected to this IP")
      {:noreply, state}
    else
      {key, iv} = authenticate_inbound(socket, state.router)

      SharedState.add_connection(state.handler_name, peername)

      state = Map.merge(state, %{
        socket: socket,
        key: key,
        iv: iv,
        peername: peername
      })

      Logger.info("#{state.handler_name}: Authenticated with peer at #{peername}")

      apply(state.router, :message, ["NEW_INBOUND_CONNECTION", nil, {state.socket, state.key, state.iv}, state])

      :inet.setopts(socket, active: true)

      {:noreply, state}
    end
  end

  def handle_cast({:attempt_outbound_connection, ip, port}, state) do
    case :gen_tcp.connect(ip, port, [:binary, active: false, packet: 4]) do
      {:ok, socket} ->
        {key, iv} = authenticate_outbound(socket)

        peername = get_peername(socket)
        SharedState.add_connection(state.handler_name, peername)

        state = Map.merge(state, %{
          socket: socket,
          key: key,
          iv: iv,
          peername: peername
        })

        Logger.info("#{state.handler_name}: Authenticated with peer at #{peername}")

        apply(state.router, :message, ["NEW_OUTBOUND_CONNECTION", nil, {state.socket, state.key, state.iv}, state])

        :inet.setopts(socket, active: true)

        {:noreply, state}

      {:error, reason} ->
        Logger.warn("#{state.handler_name} -- Error connecting to peer: #{reason}. Starting listener instead.")

        GenServer.cast(state.handler_name, :accept_inbound_connection)

        {:noreply, state}
    end
  end

  def handle_cast({:message_peer, opname, data}, state) do
    if data do
      Pico.message({state.socket, state.key, state.iv}, opname, data)
    else
      Pico.message({state.socket, state.key, state.iv}, opname)
    end

    {:noreply, state}
  end

  @spec authenticate_inbound(pid, atom) :: {binary, binary} | {:error, :closed}
  defp authenticate_inbound(socket, router) do
    {opname, data} = read_single_message(socket)

    <<key::binary-size(32), iv::binary-size(16), _rest::binary>> = apply(router, :message, [opname, data, socket])

    {key, iv}
  end

  @spec authenticate_outbound(pid) :: {binary, binary} | {:error, any}
  defp authenticate_outbound(socket) do
    {prime, generator} = Strap.prime_group(1024)
    identifier = :crypto.strong_rand_bytes(32)
    password = :crypto.strong_rand_bytes(32)
    salt = :crypto.strong_rand_bytes(32)

    client =
      :srp6a
      |> Strap.protocol(prime, generator)
      |> Strap.client(identifier, password, salt)

    Pico.message(socket, "HANDSHAKE", %{
      prime: prime,
      generator: generator,
      verifier: Strap.verifier(client),
      public_value: Strap.public_value(client)
    })

    {"HANDSHAKE_AUTH", %{public_value: peer_public_value}} = read_single_message(socket)

    {:ok, shared_secret} = Strap.session_key(client, peer_public_value)

    <<key::binary-size(32), iv::binary-size(16), _rest::binary>> = shared_secret

    {key, iv}
  end

  # Returns a string containing the IP of whoever is on the other end
  # of the given socket
  @spec get_peername(reference) :: String.t()
  defp get_peername(socket) do
    {:ok, {addr, _port}} = :inet.peername(socket)

    addr
    |> :inet_parse.ntoa()
    |> to_string()
  end

  @spec abort_connection(String.t) :: none
  defp abort_connection(reason) do
    Logger.info(reason)
    Process.exit(self(), :normal)
  end

end
