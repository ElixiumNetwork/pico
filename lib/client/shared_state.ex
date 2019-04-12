defmodule Pico.Client.SharedState do
  use Agent

  def start_link do
    initial = %{
      internal: %{
        connections: []
      },
      external: %{}
    }

    Agent.start_link(fn -> initial end, name: __MODULE__)
  end

  def connections do
    Agent.get(__MODULE__, fn %{internal: %{connections: conn}} -> conn end)
  end

  def add_connection(handler, ip) do
    Agent.update(__MODULE__, fn state ->
      conn = Keyword.put(state.internal.connections, handler, ip)

      internal = Map.put(state.internal, :connections, conn)
      Map.put(state, :internal, internal)
    end)
  end

  def remove_connection(handler) do
    Agent.update(__MODULE__, fn state ->
      conn = Keyword.delete(state.internal.connections, handler)

      internal = Map.put(state.internal, :connections, conn)
      Map.put(state, :internal, internal)
    end)
  end

  def get(key) do
    Agent.get(__MODULE__, fn %{external: state} -> Map.get(state, key) end)
  end

  def set(key, value) do
    Agent.update(__MODULE__, fn state ->
      external = Map.put(state.external, key, value)

      Map.put(state, :external, external)
    end)
  end
end
