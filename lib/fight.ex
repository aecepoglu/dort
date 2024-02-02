defmodule Fight do
  use GenServer
  require Logger

  defstruct [state: :on,
             board: %Board{},
             tick: 0,
             p1: nil,
             p2: nil]

  def start_link(player1, player2) do
    GenServer.start_link(__MODULE__, {player1, player2})
  end

  def find(player_id) do
    Registry.lookup(Dispatcher.Registry, player_id)
  end

  @impl true
  def init({player1_id, player2_id}) do
    {:ok, ^player1_id, sock1} = Connections.fetch_with_player(player1_id)
    {:ok, ^player2_id, sock2} = Connections.fetch_with_player(player2_id)
    state = %Fight{p1: {player1_id, sock1},
                   p2: {player2_id, sock2}}
    
    {:matchmade, player2_id, :white} |> Message.make() |> Connection.say(sock1)
    {:matchmade, player1_id, :black} |> Message.make() |> Connection.say(sock2)

    board_str = {:state, state.board, 0} |> Message.make()
    board_str |> Connection.say(sock1)
    board_str |> Connection.say(sock2)

    Registry.unregister(Dispatcher.Registry, player1_id)
    Registry.unregister(Dispatcher.Registry, player2_id)
    {:ok, _} = Registry.register(Dispatcher.Registry, player1_id, [])
    {:ok, _} = Registry.register(Dispatcher.Registry, player2_id, [])
    {:ok, state}
  end

  @impl true
  def handle_info({{:move, move}, player}, %Fight{p1: p1, p2: p2}=state) do
    color = get_color(p1, p2, player)

    state
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

  def handle_info({:disconnect, player_id}, %Fight{p1: {id1, _}, p2: {id2, _}}=state) do
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

  defp do_da_move(%Fight{state: :on, board: b}=state, {:repopulate, a}, player, color) do
    Logger.info("#{player}[#{color}] repopulates #{a}")
    %{state | board: Board.repopulate(b, a, color)}
  end
  defp do_da_move(%Fight{state: :on, board: b}=state, {:aid, a1, a2}, player, color) do
    Logger.info("#{player}[#{color}] sends aid from #{a1} to #{a2}")
    %{state | board: Board.aid(b, a1, a2, color)}
  end
  defp do_da_move(%Fight{state: :on, board: b}=state, {:attack, a1, a2}, player, color) do
    Logger.info("#{player}[#{color}] attacks from #{a1} to #{a2}")
    %{state | board: Board.attack(b, a1, a2, color)}
  end

  defp gameover_maybe(%Fight{state: :on, board: b}=state) do
    case Board.fin?(b) do
      {true, s} -> %{state | state: s} |> broadcast
      false     -> state
    end
  end
  defp gameover_maybe(%Fight{}=state), do: state

  defp respond(%Fight{state: :on}=state) do
    {:noreply, state}
  end
  defp respond(%Fight{p1: {id1, _}, p2: {id2, _}}=state) do
    :ok = Registry.unregister(Dispatcher.Registry, id1)
    :ok = Registry.unregister(Dispatcher.Registry, id2)
    {:stop, :gameover, state}
  end
  
  defp broadcast(%Fight{}=state) do
    case state.state do
      :on -> {:state, state.board, state.tick}
      fin -> fin
    end
    |> Message.make
    |> say(state.p1, state.p2)
    state
  end

  defp incr_counter(%Fight{state: :on, tick: n}=state) do
    %{state | tick: n + 1}
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
  
  defp assc(%Fight{p1: {id1, s1}=p1, p2: {id2, s2}=p2}, id) do
    cond do
      id1 == id -> {{p1, s1}, {p2, s2}}
      id2 == id -> {{p2, s2}, {p1, s1}}
    end
  end
end
