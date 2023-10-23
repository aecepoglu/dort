defmodule Board do
  @areas [:nw, :ne, :se, :sw]
  @players [:white, :black]
  defstruct [nw: :empty,
             ne: :empty,
             se: :empty,
             sw: :empty]

  def repopulate(%__MODULE__{}=board, area, player)
  when area in @areas
  and player in @players do
     %{board | area => repopulate_area(board[area], player)}
  end

  def attack(%__MODULE__{}=board, from, to)
  when from in @areas and to in @areas do
    f = board[from]
    t = board[to]
    %{board | from => :empty, to => attack_area(f, t)}
  end

  defp repopulate_area(:empty, player) do
    {player, 1}
  end
  defp repopulate_area({owner, n}, player) when player == owner do
    n_ = case n do
      1 -> 2
      2 -> 4
      k -> k
    end
    {owner, n_}
  end
  defp repopulate_area(area, _player), do: area

  defp attack_area(:empty, atker), do: atker
  defp attack_area({defder, n}, {atker, k}) when atker == defder do
    {defder, n + k}
  end
  defp attack_area({_, n}, {_, k}) when n == k, do: :empty
  defp attack_area({defder, n}, {atker, k}) do
    if greater?(n, k) do
      {defder, max(0, n - k)}
    else
      {atker, max(0, k - n)}
    end
  end

  def greater?(n, k) do
    case {n, k} do
      {a, b} when a == b -> false
      {_, 0} -> true
      {1, 6} -> true
      {6, 1} -> false
      {a, b} -> a > b
    end
  end

  def string(%__MODULE__{}=x) do
    [x.nw, x.ne, x.sw, x.se]
    |> Enum.map(&string_area/1)
    |> Enum.chunk_every(2)
    |> Enum.map(fn [a, b] -> Enum.zip_with(a, b, & &1 <> "|" <> &2) end)
    |> Enum.intersperse(["--- ---"])
    |> Enum.flat_map(& &1)
    |> Enum.join("\n")
  end

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
end
