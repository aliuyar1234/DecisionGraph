defmodule DecisionGraphBeam.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      aliases: aliases(),
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"],
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      version: "0.1.0",
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: preferred_cli_env()
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "do --app dg_store ecto.setup"],
      check: ["format --check-formatted", "credo --strict", "test"],
      "ecto.setup": ["do --app dg_store ecto.setup"],
      "ecto.reset": ["do --app dg_store ecto.reset"]
    ]
  end

  defp preferred_cli_env do
    [
      check: :test,
      credo: :test,
      dialyzer: :dev
    ]
  end
end
