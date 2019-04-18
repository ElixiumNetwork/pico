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

      def message("NEW_INBOUND_CONNECTION", _, _, _), do: :ok

      def message("NEW_OUTBOUND_CONNECTION", _, _, _), do: :ok

      def message(opname, _data, _conn, _handler_state) do
        IO.puts "Received unknown message #{opname}. Terminating connection"
        Process.exit(self(), :normal)
      end

      def message("HANDSHAKE", %{public_value: peer_pub, generator: gen, prime: prime, verifier: verifier}, socket) do
        server =
          :srp6a
          |> Strap.protocol(prime, gen)
          |> Strap.server(verifier)

        Pico.message(socket, "HANDSHAKE_AUTH", %{public_value: Strap.public_value(server)})

        {:ok, shared_master_key} = Strap.session_key(server, peer_pub)

        shared_master_key
      end
      
      defoverridable [message: 4, message: 3]
    end
  end

end
