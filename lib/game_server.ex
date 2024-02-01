defmodule GameServer do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: GameServer)
  end

  def register(player_id) do
    GenServer.call(__MODULE__, {:register, player_id})
  end
  def unregister(player_id) do
    GenServer.call(__MODULE__, {:unregister, player_id})
  end

  @impl true
  def init(val) do
    {:ok, val}
  end

  @impl true
  def handle_call({:register, player_id}, _from, state) do
    {:ok, _} = Registry.register(Dispatcher.Registry, player_id, [])
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:disconnect, player_id}, state) do
    Matchmaking.dequeue(player_id)
    :ok = Registry.unregister(Dispatcher.Registry, player_id)
    {:noreply, state}
  end
  def handle_info({:matchmake, player_id}, state) do
    case Matchmaking.enqueue(player_id) do
      {:found, p1, p2} ->
        Registry.unregister(Dispatcher.Registry, p1)
        Registry.unregister(Dispatcher.Registry, p2)
        {:ok, pid} = Fight.start_link(p1, p2)
        Process.monitor(pid)
      _ -> nil
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :abandoned}, state) do
     {:noreply, state}
  end
end
