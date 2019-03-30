defmodule Pico do
  alias Pico.Protocol.Encoder
  @moduledoc """
  Documentation for Pico.
  """

  @type connection :: {pid, binary}

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

        <<shared_secret::binary-size(32)>> <> _ = shared_secret

        {:ok, {socket, shared_secret}}
      e -> e
    end
  end

  @doc """
    Listen for incoming connections on the given port, or port 31013 by default.
  """
  @spec listen(atom, integer, integer) :: {:ok, pid} | {:error, String.t}
  def listen(router, port \\ 31013, handlers \\ 10) do
    Pico.Client.Supervisor.start_link(router, port, handlers)
  end

  def stop_listening(pid), do: Pico.Client.Supervisor.stop(pid)

  def listen do
    {:error, "No router specified for Pico handler."}
  end

  @doc """
    Send a message containing only an OpName to a connection.
  """
  @spec message(connection, String.t) :: :ok | {:error, String.t}
  def message({socket, key}, opname) do
    opname
    |> encode(key)
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
  def message({socket, key}, opname, data) do
    opname
    |> encode(data, key)
    |> send_message(socket)
  end

  def message(socket, opname, data) do
    opname
    |> Encoder.encode(data)
    |> send_message(socket)
  end

  @spec encode(String.t, binary) :: binary | {:error, String.t}
  def encode(opname, key), do: Encoder.encode(opname, <<0>>, key)

  @spec encode(String.t, map, binary) :: binary | {:error, String.t}
  def encode(opname, data, key), do: Encoder.encode(opname, data, key)

  @spec send_message(binary, pid) :: :ok | tuple
  defp send_message(message, socket), do: :gen_tcp.send(socket, message)
end
