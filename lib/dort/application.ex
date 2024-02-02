defmodule Dort.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:dort, :port, 4000)
    children = [
      {Task.Supervisor, name: TCPServer.TaskSupervisor},
      {Registry, keys: :duplicate, name: Dispatcher.Registry},
      GameServer,
      Matchmaking,
      Connections,
      Supervisor.child_spec(
        {Task, fn -> TCPServer.accept(port) end}, restart: :permanent
      )
    ]

    opts = [strategy: :one_for_one, name: Dort.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
