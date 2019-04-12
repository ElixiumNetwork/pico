defmodule Pico.Client.Supervisor do
  use Supervisor
  alias Pico.Client.SharedState

  def start_link(args) do
    SharedState.start_link()
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init({router, peers, port, handlers}) do
    case :gen_tcp.listen(port, [:binary, reuseaddr: true, active: false, packet: 4]) do
      {:ok, socket} ->
        handlers = generate_handlers(socket, router, handlers, peers)
        Supervisor.init(handlers, strategy: :one_for_one, max_restarts: length(handlers))

      e -> e
    end
  end

  def handlers do
    __MODULE__
    |> Process.whereis()
    |> Supervisor.which_children()
    |> Enum.map(fn {name, pid, _, _} -> {name, pid} end)
  end

  defp generate_handlers(socket, router, count, peers) do
    for i <- 1..count do
      handler_name = :"PicoHandler#{i}"

      %{
          id: handler_name,
          start: {
            Pico.Client.Handler,
            :start_link,
            [socket, router, handler_name, i, peers]
          },
          type: :worker,
          restart: :permanent
        }
    end
  end
end
