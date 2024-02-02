defmodule Fight do
  use GenServer
  require Logger

  def start_link(player1, player2) do
    GenServer.start_link(__MODULE__, {player1, player2})
  end

  def find(player_id) do
    Registry.lookup(Dispatcher.Registry, player_id)
  end

  @impl true
  def init({player1_id, player2_id}) do
    board = %Board{}
    {:ok, ^player1_id, sock1} = Connections.fetch_with_player(player1_id)
    {:ok, ^player2_id, sock2} = Connections.fetch_with_player(player2_id)
    
    {:matchmade, player2_id, :white} |> Message.make() |> Connection.say(sock1)
    {:matchmade, player1_id, :black} |> Message.make() |> Connection.say(sock2)

    board_str = {:state, board, 0} |> Message.make()
    board_str |> Connection.say(sock1)
    board_str |> Connection.say(sock2)

    Registry.unregister(Dispatcher.Registry, player1_id)
    Registry.unregister(Dispatcher.Registry, player2_id)
    {:ok, _} = Registry.register(Dispatcher.Registry, player1_id, [])
    {:ok, _} = Registry.register(Dispatcher.Registry, player2_id, [])
    {:ok, {:on, board, 0, {player1_id, sock1}, {player2_id, sock2}}}
  end

  @impl true
  def handle_info({{:move, move}, player}, {:on, _, _, p1, p2}=state) do
    color = get_color(p1, p2, player)

    state_ = state
    |> do_da_move(move, player, color)
    |> incr_counter
    |> broadcast
    |> gameover_maybe
    |> respond
  end
  def handle_info({{:move, _}, _player}, state) do
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:disconnect, player_id},
                  {_, _board, _counter, {id1, _}, {id2, _}}=state) do
    :ok = Registry.unregister(Dispatcher.Registry, id1)
    :ok = Registry.unregister(Dispatcher.Registry, id2)
    {_, {other_id, sock}} = assc(state, player_id)
    :abandoned |> Message.make |> Connection.say(sock)
    Matchmaking.enqueue(other_id)
    {:stop, :abandoned, nil}
  end

  def handle_info({{:bubble, _}=msg, player_id}, state) do
    {_, {_, s_other}} = assc(state, player_id)
    msg |> Message.make |> Connection.say(s_other)
    {:noreply, state}
  end

  defp do_da_move({:on, board, counter, p1, p2}, {:repopulate, a1}, player, color) do
    Logger.info("#{player}[#{color}] repopulates #{a1}")
    {:on, Board.repopulate(board, a1, color), counter, p1, p2}
  end
  defp do_da_move({:on, board, counter, p1, p2}, {:aid, a1, a2}, player, color) do
    Logger.info("#{player}[#{color}] sends aid from #{a1} to #{a2}")
    {:on, Board.aid(board, a1, a2, color), counter, p1, p2}
  end
  defp do_da_move({:on, board, counter, p1, p2}, {:attack, a1, a2}, player, color) do
    Logger.info("#{player}[#{color}] attacks from #{a1} to #{a2}")
    {:on, Board.attack(board, a1, a2, color), counter, p1, p2}
  end

  defp gameover_maybe({:on, board, counter, p1, p2}=state) do
    case Board.fin?(board) do
      {true, x} -> {x, board, counter, p1, p2} |> broadcast
      false     -> state
    end
  end
  defp gameover_maybe({_status, _board, _counter, _, _}=state) do
    state
  end

  defp respond({:on, _board, _counter, _, _}=state) do
    {:noreply, state}
  end
  defp respond({_s, _b, _c, {id1, _}=p1, {id2, _}=p2}=state) do
    :ok = Registry.unregister(Dispatcher.Registry, id1)
    :ok = Registry.unregister(Dispatcher.Registry, id2)
    {:stop, :gameover, state}
  end
  
  defp broadcast({status, board, counter, p1, p2}=state) do
    case status do
      :on -> {:state, board, counter}
      fin -> fin
    end
    |> Message.make
    |> say(p1, p2)
    state
  end

  defp incr_counter({:on, board, counter, p1, p2}) do
    {:on, board, counter + 1, p1, p2}
  end

  defp say(str, {_, s1}, {_, s2}) do
    Connection.say(str, s1)
    Connection.say(str, s2)
  end

  defp get_color({p1, _}, {p2, _}, id) do
    cond do
      p1 == id -> :white
      p2 == id -> :black
      # TODO need to handle if it's an alien massage?
    end
  end
  defp assc({_, _board, _counter, {id1, s1}=p1, {id2, s2}=p2}, id) do
    cond do
      id1 == id -> {{p1, s1}, {p2, s2}}
      id2 == id -> {{p2, s2}, {p1, s1}}
    end
  end
end
