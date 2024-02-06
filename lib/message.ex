defmodule Message do
  def make(:ping), do: "ping"
  def make(:pong), do: "pong"
  def make(:unidentified), do: "who are you?"
  def make(:mismatch), do: "you cannot do that"

  def make({:bubble, x}) do
    s = case x do
      :hi -> "hi"
      :gg -> "gg"
      :rematch -> "rematch"
      :yes -> "yes"
      :no -> "no"
    end
    "bubble #{s}"
  end
  
  def make({:enqueued, _id}), do: "enqueued"
  def make(:welcome), do: "welcome"
  def make({:identify, name}), do: "i am #{name}"
  def make({:join_matchmaking, region}), do: "matchmake #{region_to_str(region)}"
  def make({:matchmade, name, color}), do: "found #{name} . ready #{color_to_str(color)}"
  def make({:move, {:attack, from, to}}), do: "move attack #{from} #{to}"
  def make({:move, {:repopulate, area}}), do: "move repopulate #{area}"
  def make({:move, {:aid, from, to}}), do: "move aid #{from} #{to}"
  def make({:state, %Board{}=b, counter}), do: "state #{counter} " <> Board.serialize(b)
  def make(:abandoned), do: "abandoned"
  def make({:win, color}), do: "gameover wins #{color}"
  def make(:draw), do: "gameover draw"

  def parse("ping"), do: {:ok, :ping}
  def parse("pong"), do: {:ok, :pong}
  def parse("who are you?"), do: {:ok, :unidentified}
  def parse("you cannot do that"), do: {:ok, :mismatch}
  def parse("i am " <> player_id), do: {:ok, {:i_am, player_id}}
  def parse("matchmake " <> region), do: {:ok, {:matchmake,
                                                String.to_existing_atom(region)}}
  def parse("welcome"), do: {:ok, :welcome}
  def parse("enqueued"), do: {:ok, :enqueued}
  def parse("move repopulate " <> area) do
    case parse_area(area) do
      {:ok, area} -> {:ok, {:move, {:repopulate, area}}}
      err -> err
    end
  end
  def parse("move attack " <> str) do
    with [s1, s2] <- String.split(str, " "),
         {:ok, a1} <- parse_area(s1),
         {:ok, a2} <- parse_area(s2)
    do
      {:ok, {:move, {:attack, a1, a2}}}
    else
      {:error, _}=err -> err
      _ -> {:error, "couldn't parse attack #{str}"}
    end
  end
  def parse("move aid " <> str) do
    with [s1, s2] <- String.split(str, " "),
         {:ok, a1} <- parse_area(s1),
         {:ok, a2} <- parse_area(s2)
    do
      {:ok, {:move, {:aid, a1, a2}}}
    else
      {:error, _}=err -> err
      _ -> {:error, "couldn't parse aid #{str}"}
    end
  end
  def parse(("found " <> _) = msg) do
    with ["found", name, ".", "ready", color_str] <- String.split(msg, " "),
         {:ok, color} <- parse_color(color_str) do
      {:ok, {:matchmade, name, color}}
    else
      err -> {:error, err}
    end
  end
  def parse("state " <> state) do
    with [num_str, board_str] <- String.split(state, " ", parts: 2),
         {time, _} <- Integer.parse(num_str),
         board <- Board.deserialize(board_str)
    do
      {:ok, {:state, time, board}}
    else
      {:error, _}=err -> err
      err -> err
    end
  end
  def parse("gameover wins " <> color), do: {:gameover, :win, String.to_existing_atom(color)}
  def parse("gameover draw"), do: {:gameover, :draw}
  def parse("abandoned"), do: {:ok, :abandoned}
  def parse(("bubble " <> b)=cmd) do
    a = case b do
      "hi" -> :hi
      "gg" -> :gg
      "rematch" -> :rematch
      "yes" -> :yes
      "no" -> :no
      _ -> nil
    end
    if a == nil do
      {:error, {:unknown_cmd, cmd}}
    else
      {:ok, {:bubble, a}}
    end
  end
  def parse(msg), do: {:error, {:unknown_cmd, msg}}

  def parse_area("nw"), do: {:ok, :nw}
  def parse_area("ne"), do: {:ok, :ne}
  def parse_area("se"), do: {:ok, :se}
  def parse_area("sw"), do: {:ok, :sw}
  def parse_area(area), do: {:error, "bad area #{area}"}

  defp parse_color("W"), do: {:ok, :white}
  defp parse_color("B"), do: {:ok, :black}
  defp parse_color(x), do: {:error, {:unknown_color, x}}

  defp color_to_str(:white), do: "W"
  defp color_to_str(:black), do: "B"

  defp region_to_str(:earth), do: "earth"
  defp region_to_str(:mars), do: "mars"
end
