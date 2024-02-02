defmodule FlowTest do
  use ExUnit.Case

  setup do
    Application.stop(:dort)
    Application.start(:dort)
    Process.sleep(250)
  end

  setup do
    c1 = Client.connect('localhost', 4001)
    c2 = Client.connect('localhost', 4001)

    on_exit(:disconnect, fn ->
        Client.close(c1)
        Client.close(c2)
      end)

    %{socket1: c1, socket2: c2}
  end

  test "disconnected players are removed from the matchmaking queue",
       %{socket1: sock1, socket2: _sock2} do
    assert :welcome
      == Client.identify("aecepoglu", sock1)
    assert :enqueued
      == Client.join_matchmaking(sock1)

    :gen_tcp.close(sock1)
    Process.sleep(100)
    
    assert Matchmaking.list() == []
    assert Connections.fetch_with_player("aecepoglu") == :error
  end

  test "matches don't die when a player quits", %{socket1: sock1,
                                                       socket2: sock2} do
    start_a_match("aecepoglu", sock1, "tanshaydar", sock2)

    :gen_tcp.close(sock1)
    Process.sleep(100)

    assert Client.recv(sock2) == :abandoned
    assert Fight.find("aecepoglu") != []
  end

  test "abandoned player maintains their connection", %{socket1: sock1,
                                                       socket2: sock2} do
    start_a_match("aecepoglu", sock1, "tanshaydar", sock2)

    :gen_tcp.close(sock1)
    Process.sleep(100)

    assert Client.recv(sock2) == :abandoned
    assert Client.ping(sock2) == :pong
  end

  test "players identify, join a match, fight, win",
       %{socket1: sock1,
         socket2: sock2} do
    start_a_match("aecepoglu", sock1, "tanshaydar", sock2)

    assert Client.repopulate(:se, sock1)
           == {:state, 1, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:white, 2},
                                 se: {:black, 4}}}

    assert Client.recv(sock2)
           == {:state, 1, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:white, 2},
                                 se: {:black, 4}}}

    assert Client.attack({"se", "sw"}, sock1)
           == {:state, 2, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:black, 1},
                                 se: {:black, 1}}}
    assert Client.recv(sock2)
           == {:state, 2, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:black, 1},
                                 se: {:black, 1}}}

    assert Client.attack({"ne", "nw"}, sock1)
           == {:state, 3, %Board{nw: :empty,
                                 ne: :empty,
                                 sw: {:black, 1},
                                 se: {:black, 1}}}
    assert Client.recv(sock2)
           == {:state, 3, %Board{nw: :empty,
                                 ne: :empty,
                                 sw: {:black, 1},
                                 se: {:black, 1}}}
    assert Client.recv(sock1)
      == {:gameover, :win, :black}
    assert Client.recv(sock2)
      == {:gameover, :win, :black}

    assert {Fight.find("aecepoglu"), Fight.find("tanshaydar")}
           == {[], []}

    matchmake("aecepoglu", sock1, "tanshaydar", sock2)
  end

  test "players can talk to each other", %{socket1: s1, socket2: s2} do
    start_a_match("aecepoglu", s1, "tanshaydar", s2)
    
    Client.bubble(:hi, s1)
    assert Client.recv(s2) == {:bubble, :hi}

    assert Client.bubble(:gg, s1) == :ok
    assert Client.recv(s2) == {:bubble, :gg}

    assert Client.bubble(:rematch, s2) == :ok
    assert Client.recv(s1) == {:bubble, :rematch}
  end

  test "players can reconnect to matches", %{socket1: s1, socket2: s2} do
    start_a_match("aecepoglu", s1, "tanshaydar", s2)

    assert Client.repopulate(:se, s1)
           == {:state, 1, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:white, 2},
                                 se: {:black, 4}}}
    assert Client.recv(s2)
           == {:state, 1, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:white, 2},
                                 se: {:black, 4}}}
    
    :gen_tcp.close(s2)
    s2new = Client.connect('localhost', 4001)
    on_exit(fn -> :gen_tcp.close(s2new) end)

    assert Client.identify("tanshaydar", s2new)
           == {:matchmade, "aecepoglu", :white}
    
    assert Client.recv(s2new)
           == {:state, 1, %Board{nw: {:white, 4},
                                 ne: {:black, 4},
                                 sw: {:white, 2},
                                 se: {:black, 4}}}
  end
    
  
  defp start_a_match(p1, s1, p2, s2) do
    assert Client.identify(p1, s1)
           == :welcome

    assert Client.identify(p2, s2)
           == :welcome

    matchmake(p1, s1, p2, s2)
  end

  defp matchmake(p1, s1, p2, s2) do
    assert Client.join_matchmaking(s1)
           == :enqueued

    assert Client.join_matchmaking(s2)
           == {:matchmade, p1, :white}

    assert Client.recv(s1)
           == {:matchmade, p2, :black}
    assert Client.recv(s1)
           == {:state, 0, %Board{}}

    assert Client.recv(s2)
           == {:state, 0, %Board{}}
  end
end
