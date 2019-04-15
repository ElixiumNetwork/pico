defmodule Pico do
  alias Pico.Protocol.Encoder
  alias Pico.Client.SharedState
  @moduledoc """
  Documentation for Pico.
  """

  @type connection :: {pid, binary, binary}

  @doc """
    Attempt a connection to the given IP address on the given port. This
    will go through all authentication steps.
  """
  @spec connect(bitstring, integer) :: {:ok, connection} | {:error, String.t}
  def connect(ip, port \\ 31013) do
    case :gen_tcp.connect(ip, port, [:binary, active: false, packet: 4]) do
      {:ok, socket} ->
        {prime, generator} = Strap.prime_group(1024)
        identifier = :crypto.strong_rand_bytes(32)
        password = :crypto.strong_rand_bytes(32)
        salt = :crypto.strong_rand_bytes(32)

        client =
          :srp6a
          |> Strap.protocol(prime, generator)
          |> Strap.client(identifier, password, salt)

        message(socket, "HANDSHAKE", %{
          prime: prime,
          generator: generator,
          verifier: Strap.verifier(client),
          public_value: Strap.public_value(client)
        })

        {"HANDSHAKE_AUTH", %{public_value: peer_public_value}} =
          Pico.Client.Handler.read_single_message(socket)

        {:ok, shared_secret} = Strap.session_key(client, peer_public_value)

        <<key::binary-size(32), iv::binary-size(16), _rest::binary>> = shared_secret

        {:ok, {socket, key, iv}}
      e -> e
    end
  end

  @doc """
    Listen for incoming connections on the given port, or port 31013 by default.
  """
  @spec start(atom, list, integer, integer) :: {:ok, pid} | {:error, String.t}
  def start(router, peers \\ [], port \\ 31013, handlers \\ 10) do
    Pico.Client.Supervisor.start_link({router, peers, port, handlers})
  end

  def start, do: {:error, "No router specified for Pico handler."}

  def handlers, do: Pico.Client.Supervisor.handlers()

  def connected_handlers, do: SharedState.connections()

  def listen(handler_pid), do: Pico.Client.Handler.accept_inbound_connection(handler_pid)

  def listen_all_handlers do
    Pico.handlers() |> Enum.each(fn {_, pid} -> Pico.listen(pid) end)
  end

  def broadcast(opname, data \\ nil) do
    Enum.each(connected_handlers(), fn {pid, _} ->
      Pico.Client.Handler.message_peer(pid, opname, data)
    end)
  end

  @doc """
    Send a message containing only an OpName to a connection.
  """
  @spec message(connection, String.t) :: :ok | {:error, String.t}
  def message({socket, key, iv}, opname) do
    opname
    |> encode(key, iv)
    |> send_message(socket)
  end

  def message(socket, opname) do
    opname
    |> Encoder.encode(<<0>>)
    |> send_message(socket)
  end

  @doc """
    Send a message to a connection.
  """
  @spec message(connection, String.t, map) :: :ok | {:error, String.t}
  def message({socket, key, iv}, opname, data) do
    encoded = encode(opname, data, key, iv)

    send_message(encoded, socket)
  end

  def message(socket, opname, data) do
    opname
    |> Encoder.encode(data)
    |> send_message(socket)
  end

  @spec encode(String.t, binary, binary) :: binary | {:error, String.t}
  def encode(opname, key, iv), do: Encoder.encode(opname, <<0>>, key, iv)

  @spec encode(String.t, map, binary, binary) :: binary | {:error, String.t}
  def encode(opname, data, key, iv), do: Encoder.encode(opname, data, key, iv)

  @spec send_message(binary, pid) :: :ok | tuple
  defp send_message(message, socket), do: :gen_tcp.send(socket, message)
end
