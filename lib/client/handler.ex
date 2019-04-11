defmodule Pico.Client.Handler do
  alias Pico.Protocol.Decoder
  use GenServer
  require IEx
  require Logger

  def start_link(socket, router, handler_name, handler_number, peers) do
    GenServer.start_link(__MODULE__, [socket, router, handler_name, handler_number, peers], name: handler_name)
  end

  def init([socket, router, handler_name, handler_number, peers]) do
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

  def accept_inbound_connection(handler) do
    GenServer.cast(handler, :accept_inbound_connection)
  end

  def attempt_outbound_connection(handler, ip, port \\ 31013) do
    GenServer.cast(handler, {:attempt_outbound_connection, ip, port})
  end

  def message_peer(handler, opname, data) do
    GenServer.call(handler, {:message_peer, opname, data})
  end

  @spec read_single_message(pid, binary) :: {String.t, map | nil}
  def read_single_message(socket, secret \\ nil) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, message} -> Decoder.decode(message, secret)
      {:error, :closed} -> Process.exit(self(), :normal)
    end
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

  def handle_info({:tcp_closed, _}, state) do
    Logger.info("Lost connection from peer: #{state.peername}. TCP closed")
    Process.exit(self(), :normal)
  end

  def handle_info(:start_connection, state) do
    case state.peers do
      [] ->
        Logger.warn("#{state.handler_name}: No known peers! Accepting inbound connections instead.")
        GenServer.cast(state.handler_name, :accept_inbound_connection)

      peers ->
        if length(peers) >= state.handler_number do
          {ip, port} = Enum.at(peers, state.handler_number - 1)
          GenServer.cast(state.handler_name, {:attempt_outbound_connection, ip, port})
        else
          Logger.info("#{state.handler_name}: No available peers. Starting listener instead.")
          GenServer.cast(state.handler_name, :accept_inbound_connection)
        end
    end

    {:noreply, state}
  end

  def handle_cast(:accept_inbound_connection, state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)

    {key, iv} = authenticate_inbound(socket, state.router)

    peername = get_peername(socket)
    Process.put(:connected, peername)

    state = Map.merge(state, %{
      socket: socket,
      key: key,
      iv: iv,
      peername: peername
    })

    :inet.setopts(socket, active: true)

    Logger.info("#{state.handler_name}: Authenticated with peer at #{peername}")

    {:noreply, state}
  end

  def handle_cast({:attempt_outbound_connection, ip, port}, state) do
    case :gen_tcp.connect(ip, port, [:binary, active: false, packet: 4]) do
      {:ok, socket} ->
        {key, iv} = authenticate_outbound(socket)

        peername = get_peername(socket)
        Process.put(:connected, peername)

        state = Map.merge(state, %{
          socket: socket,
          key: key,
          iv: iv,
          peername: peername
        })

        :inet.setopts(socket, active: true)

        Logger.info("#{state.handler_name}: Authenticated with peer at #{peername}")

        {:noreply, state}

      {:error, reason} ->
        Logger.warn("#{state.handler_name} -- Error connecting to peer: #{reason}. Starting listener instead.")

        GenServer.cast(state.handler_name, :accept_inbound_connection)

        {:noreply, state}
    end
  end

  def handle_call({:message_peer, opname, data}, _from, state) do
    if data do
      Pico.message({state.socket, state.key, state.iv}, opname, data)
    else
      Pico.message({state.socket, state.key, state.iv}, opname)
    end

    {:reply, :ok, state}
  end

  @spec authenticate_inbound(pid, atom) :: {binary, binary} | {:error, :closed}
  defp authenticate_inbound(socket, router) do
    {opname, data} = read_single_message(socket)

    <<key::binary-size(32), iv::binary-size(16), _rest::binary>> = apply(router, :message, [opname, data, socket])

    {key, iv}
  end

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

end
