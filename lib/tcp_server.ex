defmodule Connection do
  require Logger

  def starter(client) do
    fn ->
      start_serving(client)
    end
  end

  defp start_serving(socket) do
    serve(socket, :unidentified)
  end

  defp serve(socket, state) do
    aaa = socket
      |> read_line
      |> identify
      |> process(state, socket)
      |> write_line(socket)

    case aaa do
      {:error, :closed}      -> cleanup(socket, state)
      {_msg, _reply, state_} -> serve(socket, state_)
    end
  end

  defp cleanup(_sock, :unidentified), do: nil
  defp cleanup(socket, {:identified, player_id}) do
    Matchmaking.dequeue(player_id)
    Connections.unregister(player_id, socket)
    Registry.dispatch(Dispatcher.Registry, player_id, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:disconnect, player_id})
    end)
  end

  defp identify({:ok, msg}), do: Message.parse(msg)
  defp identify({:error, _}=err), do: err

  defp process({:ok, :ping}, state, _sock) do
    {:ok, Message.make(:pong), state}
  end

  defp process({:ok, {:i_am, player_id}}, :unidentified, socket) do
    reply = case Fight.find(player_id) do
      [] -> Message.make(:welcome)
      [{pid, _}] ->
        Connections.register(player_id, socket)
        
        Fight.reconnect(pid, player_id, socket)
        |> Enum.map(&Message.make/1)
        |> Enum.join("\r\n")
    end
    {:ok, reply, {:identified, player_id}}
  end
  defp process({:ok, _}, :unidentified, _sock) do
    {:ok, Message.make(:unidentified), :unidentified}
  end

  defp process({:ok, {:matchmake, region}}, {:identified, id}=state, socket) do
    Connections.register(id, socket)
    reply = case Matchmaking.enqueue(id, region) do
      {:enqueued, _}=x -> Message.make(x)
      {:found, _, _} -> :noreply
    end
    IO.inspect(reply)
    {:ok, reply, state}
  end

  defp process({:ok, cmd}, {:identified, player_id}=state, _socket) do
    # TODO try GenServer.cast({:via, Dispatcher.Registry, player_id)
    Registry.dispatch(Dispatcher.Registry, player_id, fn entries ->
      for {pid, _} <- entries do
          IO.inspect({:found, pid, cmd, player_id})
          send(pid, {cmd, player_id})
        end
    end)
    {:ok, :noreply, state}
  end

  defp process({:ok, cmd}, state, socket) do
    IO.inspect({:mismatch, cmd, state})
    {:ok, Message.make(:mismatch), socket}
  end
  defp process({:error, _}=err, _, _) do
    err
  end

  defp read_line(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        neat = String.trim_trailing(data, "\r\n")
        Logger.debug(neat)
        {:ok, neat}
      err -> err
    end
  end

  defp write_line({:ok, :noreply, _state}=left, _), do: left
  defp write_line({:ok, reply, _state}=left, socket) do
    say(reply, socket)
    left
  end
  defp write_line({:error, _}=left, _), do: left

  def say(reply, socket) do
    :ok = :gen_tcp.send(socket, reply <> "\r\n")
  end
end

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
      Connection.starter(client)
    )
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end
end
