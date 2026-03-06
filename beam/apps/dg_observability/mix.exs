defmodule DecisionGraph.Observability.MixProject do
  use Mix.Project

  def project do
    [
      app: :dg_observability,
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
      mod: {DecisionGraph.Observability.Application, []}
    ]
  end

  defp deps do
    [
      {:dg_domain, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:plug, "~> 1.16"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"}
    ]
  end
end
