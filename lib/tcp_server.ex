defmodule Fight do
  use GenServer

  def start_link(player1, player2) do
    GenServer.start_link(__MODULE__, {player1, player2})
  end

  @impl true
  def init({player1_id, player2_id}) do
    board = %Board{}
    {:ok, ^player1_id, sock1} = Connections.fetch_with_player(player1_id)
    {:ok, ^player2_id, sock2} = Connections.fetch_with_player(player2_id)
    board_str = Board.serialize(board)
    Connection.say("state #{board_str}", sock1)
    Connection.say("state #{board_str}", sock2)
    Registry.unregister(Dispatcher.Registry, player1_id)
    Registry.unregister(Dispatcher.Registry, player2_id)
    {:ok, _} = Registry.register(Dispatcher.Registry, player1_id, [])
    {:ok, _} = Registry.register(Dispatcher.Registry, player2_id, [])
    {:ok, {board, {player1_id, sock1}, {player2_id, sock2}}}
  end

  @impl true
  def handle_info({{:move, :attack, a1, a2}, _player}, {board, p1, p2}) do
    board_ = Board.attack(board, a1, a2)
    broadcast(board_, p1, p2)
    {:noreply, {board_, p1, p2}}
  end
  def handle_info({{:move, :repopulate, a1}, _player}, {board, p1, p2}) do
    board_ = Board.repopulate(board, a1, :white) # TODO not :white ofc
    broadcast(board_, p1, p2)
    {:noreply, {board_, p1, p2}}
  end

  defp broadcast(board, {_, s1}, {_, s2}) do
    str = "state " <> Board.serialize(board)
    Connection.say(str, s1)
    Connection.say(str, s2)
  end
end

defmodule Matchmaking do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def enqueue(player_id) do
    GenServer.call(__MODULE__, {:enqueue, player_id})
  end

  @impl true
  def init(nil) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:enqueue, player_id}, _, nil) do
    {:ok, ^player_id, sock} = Connections.fetch_with_player(player_id)
    Connection.say("enqueued", sock)
    {:reply, {:enqueued, player_id}, player_id}
  end
  def handle_call({:enqueue, player_id}, _, other) do
    {:ok, ^player_id, sock1} = Connections.fetch_with_player(player_id)
    {:ok, ^other, sock2} = Connections.fetch_with_player(other)
    Connection.say("found #{other}. ready W", sock1)
    Connection.say("found #{player_id}. ready B", sock2)
    {:reply, {:found, player_id, other}, nil}
  end
end

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

defmodule Parser do
  def identify("I am " <> player_id), do: {:ok, {:i_am, player_id}}
  def identify("matchmake"), do: {:ok, :matchmake}
  def identify("move repopulate " <> area) do
    case identify_area(area) do
      {:ok, area} -> {:ok, {:move, :repopulate, area}}
      err -> err
    end
  end
  def identify("move attack " <> str) do
    with [s1, s2] <- String.split(str, " "),
         {:ok, a1} <- identify_area(s1),
         {:ok, a2} <- identify_area(s2)
    do
      {:ok, {:move, :attack, a1, a2}}
    else
      {:error, _}=err -> err
      _ -> {:error, "couldn't parse attack #{str}"}
    end
  end
  def identify(cmd), do: {:error, "unknown command: #{cmd}"}

  defp identify_area("nw"), do: {:ok, :nw}
  defp identify_area("ne"), do: {:ok, :ne}
  defp identify_area("se"), do: {:ok, :se}
  defp identify_area("sw"), do: {:ok, :sw}
  defp identify_area(area), do: {:error, "bad area #{area}"}
end

defmodule GameServer do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: GameServer)
  end

  def register(player_id) do
    GenServer.call(__MODULE__, {:register, player_id})
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
  def handle_info({:matchmake, player_id}, state) do
    case Matchmaking.enqueue(player_id) do
      {:found, p1, p2} ->
        Registry.unregister(Dispatcher.Registry, p1)
        Registry.unregister(Dispatcher.Registry, p2)
        Fight.start_link(p1, p2)
      _ -> nil
    end
    {:noreply, state}
  end
end

defmodule Connection do
  def starter(client) do
    fn ->
      start_serving(client)
    end
  end

  defp start_serving(socket) do
    serve(socket, :unidentified)
  end

  defp serve(socket, state) do
    {_msg, _reply, state_} = socket
    |> read_line
    |> String.trim_trailing("\r\n")
    |> Parser.identify
    |> process(state, socket)
    |> write_line(socket)

    serve(socket, state_)
  end

  defp process({:ok, {:i_am, player_id}=msg}, _state, socket) do
    Connections.register(player_id, socket)
    GameServer.register(player_id) # <---
    {msg, "welcome", {:identified, player_id}}
  end

  defp process({:ok, _}=msg, :unidentified, _), do:
    {msg, "who r u?", :unidentified}

  defp process({:ok, :matchmake}=msg, {:identified, player_id}=state, _socket) do
    Registry.dispatch(Dispatcher.Registry, player_id, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:matchmake, player_id})
    end)
    {msg, :noreply, state}
  end
  defp process({:ok, cmd}=msg, {:identified, player_id}=state, _socket) do
    Registry.dispatch(Dispatcher.Registry, player_id, fn entries ->
      for {pid, _} <- entries, do: send(pid, {cmd, player_id})
    end)
    {msg, :noreply, state}
  end

  defp process(msg, state), do: {msg, "what?", state}

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line({_msg, :noreply, _state}=left, _), do: left
  defp write_line({_msg, reply,    _state}=left, socket) do
    say(reply, socket)
    left
  end

  def say(reply, socket) do
    :gen_tcp.send(socket, reply <> "\r\n")
  end
end

defmodule TCPServer do
  require Logger

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info("accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(
      TCPServer.TaskSupervisor,
      Connection.starter(client)
    )
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end
end
