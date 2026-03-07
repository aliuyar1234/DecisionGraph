__DIR__
|> Path.join("../test_support/**/*.exs")
|> Path.expand()
|> Path.wildcard()
|> Enum.sort()
|> Enum.each(&Code.require_file/1)

ExUnit.start()

{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:dg_domain)
{:ok, _} = Application.ensure_all_started(:dg_observability)

repo_config = DecisionGraph.Store.Repo.config()

case Ecto.Adapters.Postgres.storage_up(repo_config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end

case DecisionGraph.Store.Repo.start_link() do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

migrations_path = Application.app_dir(:dg_store, "priv/repo/migrations")
Ecto.Adapters.SQL.Sandbox.mode(DecisionGraph.Store.Repo, :auto)

{:ok, _, _} =
  Ecto.Migrator.with_repo(DecisionGraph.Store.Repo, fn repo ->
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end)

Ecto.Adapters.SQL.Sandbox.mode(DecisionGraph.Store.Repo, :manual)
