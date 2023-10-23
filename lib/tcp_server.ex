defmodule TCPServer do
  require Logger

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info("accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(
      TCPServer.TaskSupervisor,
      fn -> serve(client) end
    )
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    Logger.info("A connection")

    socket
    |> read_line
    |> String.trim_trailing("\r\n")
    |> identify
    |> response
    |> write_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp identify("I am " <> player_id), do: {:ok, {:i_am, player_id}}
  defp identify("move repopulate " <> area) do
    case identify_area(area) do
      {:ok, area} -> {:ok, {:move, :repopulate, area}}
      err -> err
    end
  end
  defp identify("move attack " <> str) do
    with [s1, s2] <- String.split(str, " "),
         {:ok, a1} <- identify_area(s1),
         {:ok, a2} <- identify_area(s2)
    do
      {:ok, {:move, :attack, a1, a2}}
    else
      {:error, _}=err -> err
      _ -> {:error, "couldn't parse attack #{str}"}
    end
  end
  defp identify(cmd), do: {:error, "unknown command: #{cmd}"}

  defp identify_area("nw"), do: {:ok, :nw}
  defp identify_area("ne"), do: {:ok, :ne}
  defp identify_area("se"), do: {:ok, :se}
  defp identify_area("sw"), do: {:ok, :sw}
  defp identify_area(area), do: {:error, "bad area #{area}"}

  defp response({:ok, _}), do: "ok"
  defp response({:error, err}), do: err

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line <> "\r\n")
  end
end
