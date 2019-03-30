defmodule Pico.Client.Supervisor do
  use Supervisor

  def start_link(router, port, handlers) do
    Supervisor.start_link(__MODULE__, {router, port, handlers}, name: __MODULE__)
  end

  def init({router, port, handlers}) do
    case :gen_tcp.listen(port, [:binary, reuseaddr: true, active: false, packet: 4]) do
      {:ok, socket} ->
        handlers = generate_handlers(socket, router, handlers)
        Supervisor.init(handlers, strategy: :one_for_one)

      _ -> :error
    end
  end

  def stop(pid) do
    [{_, child_pid, _, _} | _rest] = Supervisor.which_children(pid)

    r = GenServer.call(child_pid, :close_socket)
    IO.inspect(r, label: "Res")
  end

  defp generate_handlers(socket, router, count) do
    for i <- 1..count do
      handler_name = :"PicoHandler#{i}"

      %{
          id: handler_name,
          start: {
            Pico.Client.Handler,
            :start_link,
            [socket, router, handler_name]
          },
          type: :worker,
          restart: :permanent
        }
    end
  end
end
