defmodule FlowTest do
  use ExUnit.Case

  setup do
    {:ok, sock1} = :gen_tcp.connect('localhost', 4000,
      [:binary, packet: :line, active: false])
    {:ok, sock2} = :gen_tcp.connect('localhost', 4000,
      [:binary, packet: :line, active: false])

    on_exit(:disconnect, fn ->
      :ok = :gen_tcp.close(sock1)
      :ok = :gen_tcp.close(sock2)
      end)

    %{socket1: sock1,
      socket2: sock2,
      }
  end

  test "everything", %{socket1: sock1, socket2: sock2} do
    assert "welcome" == ask("I am aecepoglu", sock1)
    assert "welcome" == ask("I am tanshaydar", sock2)
    assert "enqueued" == ask("matchmake", sock1)
    assert "found aecepoglu. ready W" == ask("matchmake", sock2)
    assert "found tanshaydar. ready B" == recv(sock1)
    assert "state 4W 4B 2W 2B" == recv(sock1)
    assert "state 4W 4B 2W 2B" == recv(sock2)
    ## --- DONE --- until this point
    assert "state 0 0 2W 2B" == ask("move attack nw ne", sock1)
    #assert "state 0 0 2W 2B" == recv(sock2)
  end

  defp ask(msg, sock) do
    :ok = :gen_tcp.send(sock, msg <> "\r\n")
    recv(sock)
  end

  defp recv(sock) do
    {:ok, data} = :gen_tcp.recv(sock, 0, 1000)
    String.trim_trailing(data, "\r\n")
  end
end

defmodule DortTest do
  use ExUnit.Case
  doctest Dort

  test "greets the world" do
    assert Dort.hello() == :world
  end
end
