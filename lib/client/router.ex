defmodule Pico.Client.Router do
  @moduledoc """
    Provides a DSL for message routing
  """

  defmacro message(opname, data, do: block) do
    quote generated: true do
      def message(unquote(opname), unquote(data), var!(conn), var!(handler_state)) do
        unquote(block)
      end
    end
  end

  defmacro __using__(_) do
    quote do
      import Pico.Client.Router
      alias Pico.Client.SharedState

      def message(opname, _data, _conn, _handler_state) do
        IO.puts "Received unknown message #{opname}. Terminating connection"
        Process.exit(self(), :normal)
      end

      defoverridable [message: 4]

      def message("HANDSHAKE", data, socket) do
        %{
          public_value: peer_public_value,
          generator: generator,
          prime: prime,
          verifier: peer_verifier
        } = data

        server =
          :srp6a
          |> Strap.protocol(prime, generator)
          |> Strap.server(peer_verifier)

        Pico.message(socket, "HANDSHAKE_AUTH", %{public_value: Strap.public_value(server)})

        {:ok, shared_master_key} = Strap.session_key(server, peer_public_value)

        shared_master_key
      end
    end
  end

end
