defmodule DecisionGraph.Store.Release do
  @moduledoc """
  Helpers used by OTP releases to run Ecto migrations without Mix.
  """

  alias DecisionGraph.Store.Repo
  alias Ecto.Migrator

  @app :dg_store

  @spec migrate() :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Migrator.with_repo(repo, fn repo ->
          Migrator.run(repo, migrations_path(repo), :up, all: true)
        end)
    end

    :ok
  end

  @spec rollback(module(), integer()) :: :ok
  def rollback(repo \\ Repo, version) when is_integer(version) do
    load_app()

    {:ok, _, _} =
      Migrator.with_repo(repo, fn repo ->
        Migrator.run(repo, migrations_path(repo), :down, to: version)
      end)

    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp migrations_path(repo) do
    repo
    |> priv_path_for("migrations")
    |> to_string()
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.fetch!(repo.config(), :otp_app)
    Path.join([Application.app_dir(app), "priv", "repo", filename])
  end

  defp load_app do
    Application.load(@app)
  end
end
