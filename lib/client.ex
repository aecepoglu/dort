defmodule Client do
  def connect(hostname, port) do
    {:ok, sock} = :gen_tcp.connect(hostname, port, [:binary, packet: :line, active: false])
    sock
  end

  def identify(name, sock) do
    {:identify, name}
    |> Message.make()
    |> ask(sock)
  end

  def join_matchmaking(sock) do
    :join_matchmaking
    |> Message.make()
    |> ask(sock)
  end

  def attack({from, to}, sock) do
    {:move, {:attack, from, to}}
    |> Message.make()
    |> ask(sock)
  end

  def repopulate(area, sock) do
    {:move, {:repopulate, area}}
    |> Message.make()
    |> ask(sock)
  end

  def close(sock) do
    :ok = :gen_tcp.close(sock)
  end

  def ping(sock) do
    :ping
    |> Message.make
    |> ask(sock)
  end

  def bubble(bubble, sock) do
    {:bubble, bubble}
    |> Message.make
    |> say(sock)
  end

  defp ask(msg, sock) do
    :ok = say(msg, sock)
    recv(sock)
  end
  defp say(msg, sock) do
    :gen_tcp.send(sock, msg <> "\r\n")
  end

  def recv(sock, timeout \\ 1000) do
    with {:ok, data} <- :gen_tcp.recv(sock, 0, timeout),
         {:ok, msg} <- data
                       |> String.trim_trailing("\r\n")
                       |> Message.parse
    do
      msg
    else
      err -> err
    end
  end

  def print(%Board{}=b) do
    Board.pretty_string(b) |> IO.puts
    b
  end
  def print(m), do: m
end
