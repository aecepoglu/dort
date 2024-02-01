defmodule TCPClient do
  def start(player_id) do
    start('localhost', 4000, player_id)
  end
  def start(hostname, port, player_id) do
    socket = Client.connect(hostname, port)
    IO.puts("#{player_id} connected to #{hostname}:#{port}")

    :welcome = Client.identify(player_id, socket)
    IO.puts("server welcomes you.")

    IO.gets("press <return> key when you are ready to join the matchmaking queue.")
    case Client.join_matchmaking(socket) do
      :enqueued ->
        loop(socket, %{id: player_id, state: :enqueued})
      {:matchmade, opponent, my_color} ->
        loop(socket, %{id: player_id, state: :fighting, opponent: opponent, color: my_color})
    end

    Client.close(socket)
  end

  defp loop(socket, state) do
    Client.recv(socket, 5000)
    |> Client.print
    |> maybe_continue(socket, state)
  end

  defp maybe_continue(_msg, socket, state) do
    continue? = case read_input() do
      :quit -> false
      {:move, {:attack, _, _}}=move ->
        move
        |> Message.make()
        |> IO.inspect
        |> say(socket)
        true
      nil -> true
    end

    if continue? do
      loop(socket, state)
    else
      :fin
    end
  end

  defp read_input() do
    ["ENTER AN ACTION",
    "----------------",
     "q         : quits",
     "a         : attack",
     "(nothing) : keep listening...",
     ]
    |> Enum.join("\n")
    |> IO.puts

    case gets("choose > ") do
      "a" -> read_attack()
      "q" -> :quit
      "" -> nil
      _ ->
        IO.puts("bad input")
        read_input()
    end
  end

  defp read_attack() do
    with [from, to] <- gets("enter '{from} {to}' > ") |> String.split(" "),
         {:ok, a} <- Parser.identify_area(from),
         {:ok, b} <- Parser.identify_area(to)
    do
      {:move, {:attack, a, b}}
    else
      _ -> nil
    end
  end

  defp gets(prompt) do
    prompt |> IO.gets() |> String.trim_trailing()
  end

  defp say(msg, sock) do
    :ok = :gen_tcp.send(sock, msg <> "\r\n")
  end
end
