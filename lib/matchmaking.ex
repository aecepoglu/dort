defmodule Matchmaking do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def enqueue(player_id, region) do
    GenServer.call(__MODULE__, {:enqueue, player_id, region})
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
  def handle_call({:enqueue, player_id, region}, _, queue) do
    IO.inspect({:player_id, player_id, :region, region})
    {reply, state_} = case Keyword.fetch(queue, region) do
      {:ok, other_id} ->
        Fight.start_link(player_id, other_id)
        {{:found, player_id, other_id},
         List.delete(queue, {region, other_id})}
      error -> {{:enqueued, player_id},
               [{region, player_id} | queue]}
    end |> IO.inspect
    {:reply, reply, state_}
  end

  def handle_call({:dequeue, player_id}, _, queue) do
    queue_ = Enum.filter(queue, fn {_, id} -> id != player_id end)
    {:reply, :ok, queue_}
  end
  
  def handle_call(:list, _, state) do
    {:reply, state, state}
  end
end
