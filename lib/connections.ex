defmodule Connections do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def register(player_id, socket) do
    GenServer.call(__MODULE__, {:register, player_id, socket})
  end

  def unregister(player_id, socket) do
    GenServer.call(__MODULE__, {:unregister, player_id, socket})
  end

  def fetch_with_player(key) do
    GenServer.call(__MODULE__, {:get, :player, key})
  end
  
  def fetch_with_socket(key) do
    GenServer.call(__MODULE__, {:get, :socket, key})
  end


  @impl true
  def init(nil) do
     {:ok, {%{}, %{}}}
  end

  @impl true
  def handle_call({:register, player_id, socket}, _, {p2s, s2p}) do
    { :reply,
      :ok,
      { Map.put(p2s, player_id, socket),
        Map.put(s2p, socket, player_id) } }
  end
  def handle_call({:unregister, player_id, socket}, _, {p2s, s2p}) do
    { :reply,
      :ok,
      { Map.delete(p2s, player_id),
        Map.delete(s2p, socket) } }
  end
  def handle_call({:get, :player, player_id}, _, {p2s, _}=state) do
    reply = case Map.fetch(p2s, player_id) do
      {:ok, x} -> {:ok, player_id, x}
      err      -> err
    end
    {:reply, reply, state}
  end
  def handle_call({:get, :socket, socket}, _, {_, s2p}=state) do
    reply = case Map.fetch(s2p, socket) do
      {:ok, x} -> {:ok, x, socket}
      err      -> err
    end
    {:reply, reply, state}
  end
end
