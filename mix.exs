defmodule Accountabot.MixProject do
  use Mix.Project

  def project do
    [
      app: :accountabot,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: [{:postgrex, "~> 0.19"}, {:jason, "~> 1.4"}]
    ]
  end

  def application, do: [mod: {Accountabot.Application, []}, extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
