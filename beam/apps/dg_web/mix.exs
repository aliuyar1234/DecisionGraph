defmodule DecisionGraphWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :dg_web,
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixir: "~> 1.19",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      version: "0.1.0",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DecisionGraphWeb.Application, []}
    ]
  end

  defp deps do
    [
      {:dg_api, in_umbrella: true},
      {:dg_projector, in_umbrella: true},
      {:dg_observability, in_umbrella: true},
      {:bandit, "~> 1.6"},
      {:jason, "~> 1.4"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.1"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
