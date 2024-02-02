defmodule Board do
  @areas [:nw, :ne, :se, :sw]
  @players [:white, :black]
  defstruct [nw: {:white, 4},
             ne: {:black, 4},
             se: {:black, 2},
             sw: {:white, 2}]

  def repopulate(%__MODULE__{}=board, area, player)
  when area in @areas
  and player in @players do
     %{board | area => board |> Map.fetch!(area) |> repopulate_area(player)}
  end

  def attack(%__MODULE__{}=board, from, to, attacker)
      when from in @areas and to in @areas do
    defender = opposite(attacker)
    with {^attacker, a} <- Map.fetch!(board, from),
         {^defender, b} <- Map.fetch!(board, to)
    do
      {a_, b_} = case attack_area({attacker, a}, {defender, b}) do
        {^attacker, k} when k > 1 -> {{attacker, 1}, {attacker, k - 1}}
        x -> {:empty, x}
      end
      %{board | from => a_, to => b_}
    else
      _ -> board
    end
  end

  def aid(%__MODULE__{}=board, from, to, player)
  when from in @areas and to in @areas do
    with {^player, a} <- Map.fetch!(board, from),
         {^player, b} <- Map.fetch!(board, to)
    do
      {a_, b_} = aid_area(a, b)
      %{board | from => {player, a_},
                to   => {player, b_}}
    else
      _ -> board
    end
  end

  def fin?(%Board{}=board) do
    winners = board
    |> fields
    |> Enum.map(&color/1)
    |> Enum.uniq
    |> Enum.filter(fn x -> x != :empty end)

    case winners do
      []      -> {true, :draw}
      [color] -> {true, {:win, color}}
      _       -> false
    end
  end

  defp fields(%Board{}=b), do:
    [b.nw, b.ne, b.sw, b.se]

  defp repopulate_area(:empty, player), do: :empty
  defp repopulate_area({owner, n}, player) when player == owner do
    n_ = case n do
      1 -> 2
      2 -> 4
      k -> k
    end
    {owner, n_}
  end
  defp repopulate_area(area, _player), do: area

  defp attack_area({_, n}, {_, k}) when n == k, do: :empty
  defp attack_area({atk, n}, {defd, k}) do
    if greater?(n, k) do
      {atk, max(1, n - k)}
    else
      {defd, max(1, k - n)}
    end
  end

  defp aid_area(a, b) when a > b and b < 4 do
    if rem(a, 2) == 1 do
      {a - 1, b + 1}
    else
      {a - 2, b + 2}
    end
  end
  defp aid_area(a, b), do: {a, b}

  def greater?(n, k) do
    case {n, k} do
      {a, b} when a == b -> false
      {_, 0} -> true
      {1, 6} -> true
      {6, 1} -> false
      {a, b} -> a > b
    end
  end


  def pretty_string(%__MODULE__{}=x) do
    [x.nw, x.ne, x.sw, x.se]
    |> Enum.map(&string_area/1)
    |> Enum.chunk_every(2)
    |> Enum.map(fn [a, b] -> Enum.zip_with(a, b, & &1 <> "│" <> &2) end)
    |> Enum.intersperse(["───┼───"])
    |> Enum.flat_map(& &1)
    |> Enum.join("\n")
  end

  def serialize(%__MODULE__{}=x) do
    [x.nw, x.ne, x.sw, x.se]
    |> Enum.map(&serialize_area/1)
    |> Enum.join(" ")
  end
  defp serialize_area(:empty),      do: "0"
  defp serialize_area({:white, x}), do: "W#{x}"
  defp serialize_area({:black, x}), do: "B#{x}"

  def deserialize(x) when is_binary(x) do
    [nw, ne, sw, se] = String.split(x)
    |> Enum.map(&deserialize_area/1)
    %__MODULE__{
      nw: nw,
      ne: ne,
      sw: sw,
      se: se,
    }
  end
  defp deserialize_area("0"), do: :empty
  defp deserialize_area("W" <> "1"), do: {:white, 1}
  defp deserialize_area("W" <> "2"), do: {:white, 2}
  defp deserialize_area("W" <> "3"), do: {:white, 3}
  defp deserialize_area("W" <> "4"), do: {:white, 4}
  defp deserialize_area("W" <> "5"), do: {:white, 5}
  defp deserialize_area("W" <> "6"), do: {:white, 6}
  defp deserialize_area("B" <> "1"), do: {:black, 1}
  defp deserialize_area("B" <> "2"), do: {:black, 2}
  defp deserialize_area("B" <> "3"), do: {:black, 3}
  defp deserialize_area("B" <> "4"), do: {:black, 4}
  defp deserialize_area("B" <> "5"), do: {:black, 5}
  defp deserialize_area("B" <> "6"), do: {:black, 6}

  defp string_area(:empty),      do: string_num(0, " ")
  defp string_area({:white, n}), do: string_num(n, "O")
  defp string_area({:black, n}), do: string_num(n, "X")
  defp string_num(n, c) do
    case n do
      0 -> ["   ", "   "]
      1 -> [" x ", "   "]
      2 -> ["x  ", "  x"]
      3 -> [" x ", "x x"]
      4 -> ["x x", "x x"]
      5 -> ["xxx", "x x"]
      6 -> ["xxx", "xxx"]
    end
    |> Enum.map(& String.replace(&1, "x", c))
  end

  defp opposite(:black), do: :white
  defp opposite(:white), do: :black

  defp color(:empty), do: :empty
  defp color({x, _}), do: x
end
