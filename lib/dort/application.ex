defmodule Dort.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: TCPServer.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> TCPServer.accept(4000) end}, restart: :permanent
      )
    ]

    opts = [strategy: :one_for_one, name: Dort.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
