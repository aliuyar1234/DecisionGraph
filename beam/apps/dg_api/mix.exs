defmodule DecisionGraph.Api.MixProject do
  use Mix.Project

  def project do
    [
      app: :dg_api,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
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
      mod: {DecisionGraph.Api.Application, []}
    ]
  end

  defp deps do
    [
      {:dg_domain, in_umbrella: true},
      {:dg_store, in_umbrella: true},
      {:dg_projector, in_umbrella: true},
      {:dg_observability, in_umbrella: true},
      {:jason, "~> 1.4"}
    ]
  end
end
