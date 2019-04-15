defmodule Pico.Client.SharedState do
  use Agent

  @moduledoc """
    Provides a shared state that all handlers have access to
  """

  def start_link do
    initial = %{
      internal: %{
        connections: []
      },
      external: %{}
    }

    Agent.start_link(fn -> initial end, name: __MODULE__)
  end

  @doc false
  @spec connections :: list({atom, pid})
  def connections do
    Agent.get(__MODULE__, fn %{internal: %{connections: conn}} -> conn end)
  end

  @doc false
  @spec add_connection(pid, charlist) :: :ok
  def add_connection(handler, ip) do
    Agent.update(__MODULE__, fn state ->
      conn = Keyword.put(state.internal.connections, handler, ip)

      internal = Map.put(state.internal, :connections, conn)
      Map.put(state, :internal, internal)
    end)
  end

  @doc false
  @spec remove_connection(pid) :: :ok
  def remove_connection(handler) do
    Agent.update(__MODULE__, fn state ->
      conn = Keyword.delete(state.internal.connections, handler)

      internal = Map.put(state.internal, :connections, conn)
      Map.put(state, :internal, internal)
    end)
  end

  @doc """
    Get the value associated with a given key from the state
  """
  @spec get(atom) :: any
  def get(key) do
    Agent.get(__MODULE__, fn %{external: state} -> Map.get(state, key) end)
  end

  @doc """
    Update the shared state with a given key and value
  """
  @spec set(atom, any) :: :ok
  def set(key, value) do
    Agent.update(__MODULE__, fn state ->
      external = Map.put(state.external, key, value)

      Map.put(state, :external, external)
    end)
  end
end
