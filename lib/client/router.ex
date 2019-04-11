defmodule Pico.Client.Router do

  defmacro __using__(_) do
    quote do
      def message(opname, _data, _state) do
        IO.puts "Received unknown message #{opname}. Terminating connection"
        Process.exit(self(), :normal)
      end

      defoverridable [message: 3]

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
