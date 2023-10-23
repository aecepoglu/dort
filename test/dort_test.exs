defmodule DortTest do
  use ExUnit.Case
  doctest Dort

  test "greets the world" do
    assert Dort.hello() == :world
  end
end
