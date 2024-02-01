defmodule Matchmaking do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def enqueue(player_id) do
    GenServer.call(__MODULE__, {:enqueue, player_id})
  end
  def dequeue(player_id) do
    GenServer.call(__MODULE__, {:dequeue, player_id})
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  @impl true
  def init(nil) do
    {:ok, []}
  end

  @impl true
  def handle_call({:enqueue, player_id}, _, []) do
    {:reply, {:enqueued, player_id}, [player_id]}
  end

  def handle_call({:enqueue, player_id}, _, [other_id]) do
    Fight.start_link(player_id, other_id)
    {:reply, {:found, player_id, other_id}, []}
  end

  def handle_call({:dequeue, player_id}, _, [existing_id]=state) do
    state_ = if player_id == existing_id do [] else state end
    {:reply, :ok, state_}
  end
  def handle_call({:dequeue, _}, _, []), do: {:reply, :ok, []}
  
  def handle_call(:list, _, state) do
    {:reply, state, state}
  end
end
