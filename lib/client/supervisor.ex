defmodule Pico.Client.Supervisor do
  use Supervisor
  alias Pico.Client.SharedState

  def start_link(args) do
    SharedState.start_link()
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec init({atom, list, integer, integer}) :: {:ok, pid}
  def init({router, peers, port, handlers}) do
    case :gen_tcp.listen(port, [:binary, reuseaddr: true, active: false, packet: 4]) do
      {:ok, socket} ->
        handlers = generate_handlers(socket, router, handlers, peers)
        Supervisor.init(handlers, strategy: :one_for_one, max_restarts: length(handlers))

      e -> e
    end
  end

  @doc false
  @spec handlers :: list({atom, pid})
  def handlers do
    __MODULE__
    |> Process.whereis()
    |> Supervisor.which_children()
    |> Enum.map(fn {name, pid, _, _} -> {name, pid} end)
  end

  @spec generate_handlers(pid, atom, integer, list) :: list(map)
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
