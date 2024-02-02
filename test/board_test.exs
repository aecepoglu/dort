defmodule BoardTest do
  use ExUnit.Case

  test "repopulatiing empty area does nothing" do
    assert %Board{nw: :empty, ne: :empty, sw: :empty, se: :empty}
           |> Board.repopulate(:nw, :black)
           == %Board{nw: :empty, ne: :empty, sw: :empty, se: :empty}
  end

  test "black repopulates black" do
    assert %Board{nw: {:black, 2}, ne: :empty, sw: :empty, se: :empty}
           |> Board.repopulate(:nw, :black)
           == %Board{nw: {:black, 4}, ne: :empty, sw: :empty, se: :empty}
  end

  test "black cannot repopulate white's area" do
    b = %Board{nw: {:black, 2}, ne: {:white, 2}, sw: :empty, se: :empty}
    assert Board.repopulate(b, :ne, :black) == b
  end

  test "black aids from black to white area" do
    b = %Board{nw: {:black, 2}, ne: {:white, 2}, sw: :empty, se: :empty}
    assert Board.aid(b, :nw, :ne, :black) == b
  end

  test "black aids from white to white area" do
    b = %Board{nw: {:black, 2}, ne: {:white, 2}, sw: :empty, se: {:white, 3}}
    assert Board.aid(b, :se, :ne, :black) == b
  end

  test "black aids from black to black area" do
    b = %Board{nw: {:black, 6}, ne: {:white, 2}, sw: {:black, 1}, se: :empty} 
    assert Board.aid(b, :nw, :sw, :black)
           == %{b | :nw => {:black, 4}, :sw => {:black, 3}}
  end
  #TODO property tests to ensure target area can never be more than 6

  test "black attacks white and wins" do
    b = %Board{nw: {:black, 6}, ne: {:white, 3}, sw: {:black, 1}, se: :empty} 
    assert Board.attack(b, :nw, :ne, :black)
           == %{b | nw: {:black, 1}, ne: {:black, 2}}
  end

  test "black attacks white and loses" do
    b = %Board{nw: {:black, 6}, ne: {:white, 1}, sw: {:black, 1}, se: :empty} 
    assert Board.attack(b, :nw, :ne, :black)
           == %{b | nw: :empty, ne: {:white, 1}}
  end

  test "cannot attack with other player's tiles" do
    b = %Board{nw: {:black, 6}, ne: {:white, 1}, sw: :empty, se: {:white, 3}} 
    assert Board.attack(b, :se, :ne, :black)
           == b
  end
  
  test "cannot aid from empty to populated area" do
    b = %Board{nw: {:black, 5}, ne: {:white, 2}, sw: :empty, se: :empty}
    assert Board.aid(b, :sw, :nw, :black)
           == b
  end

  test "cannot aid from populated to empty area" do
    b = %Board{nw: {:black, 5}, ne: {:white, 2}, sw: :empty, se: :empty}
    assert Board.aid(b, :nw, :se, :black)
           == b
  end
  
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
