defmodule Dort.MixProject do
  use Mix.Project

  def project do
    [
      app: :dort,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Dort.Application, []}
    ]
  end

  defp deps, do: []
end
