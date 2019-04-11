defmodule Pico.Client.Supervisor do
  use Supervisor

  def start_link({router, peers, port, handlers}) do
    Supervisor.start_link(__MODULE__, {router, port, handlers, peers}, name: __MODULE__)
  end

  def init({router, port, handlers, peers}) do
    case :gen_tcp.listen(port, [:binary, reuseaddr: true, active: false, packet: 4]) do
      {:ok, socket} ->
        handlers = generate_handlers(socket, router, handlers, peers)
        Supervisor.init(handlers, strategy: :one_for_one)

      e -> e
    end
  end

  def handlers do
    __MODULE__
    |> Process.whereis()
    |> Supervisor.which_children()
    |> Enum.map(fn {name, pid, _, _} -> {name, pid} end)
  end

  def connected_handlers do
    __MODULE__
    |> Process.whereis()
    |> Supervisor.which_children()
    |> Enum.filter(fn {_, pid, _, _} ->
      pid
      |> Process.info()
      |> Keyword.get(:dictionary)
      |> Keyword.has_key?(:connected)
    end)
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
