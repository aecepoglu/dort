defmodule BoardTest do
  use ExUnit.Case

  test "game is not over" do
    x = %Board{nw: {:black, 4}, ne: :empty, sw: {:white, 1}, se: :empty}
    |> Board.fin?

    assert x == false
  end

  test "game ending in a draw" do
    x = %Board{nw: :empty, ne: :empty, sw: :empty, se: :empty}
    |> Board.fin?

    assert x == {true, :draw}
  end

  test "black wins" do
    x = %Board{nw: {:black, 1}, ne: {:black, 3}, sw: {:black, 2}, se: {:black, 5}}
    |> Board.fin?

    assert x == {true, {:win, :black}}
  end

  test "white wins" do
    x = %Board{nw: {:white, 1}, ne: {:white, 3}, sw: {:white, 2}, se: {:white, 5}}
    |> Board.fin?

    assert x == {true, {:win, :white}}
  end

  test "black wins even if empty areas are left" do
    x = %Board{nw: {:black, 1}, ne: {:black, 3}, sw: :empty, se: {:black, 5}}
    |> Board.fin?

    assert x == {true, {:win, :black}}
  end

  test "serialize and deserialize a bunch of times" do
    Enum.each(1..100, fn _ ->
        orig = random_board()
        assert orig
        |> Board.serialize()
        |> Board.deserialize()
        == orig
      end)
  end

  defp all_states() do
    non_empty = Enum.flat_map([:white, :black], fn color ->
        Enum.map(1..6, fn num -> {color, num} end)
      end)
    [:empty | non_empty]
  end

  defp random_board() do
    states = all_states()
    [a, b, c, d] = Enum.map(1..4, fn _ -> Enum.random(states) end)
    %Board{nw: a, ne: b, sw: c, se: d}
  end

end
