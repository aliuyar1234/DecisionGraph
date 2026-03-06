defmodule DecisionGraph.Domain.MixProject do
  use Mix.Project

  def project do
    [
      app: :dg_domain,
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
      extra_applications: [:crypto, :logger],
      mod: {DecisionGraph.Domain.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end
end
