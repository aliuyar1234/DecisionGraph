defmodule DecisionGraph.Store.Repo do
  @moduledoc "Primary Ecto repo for the BEAM platform."

  use Ecto.Repo,
    otp_app: :dg_store,
    adapter: Ecto.Adapters.Postgres
end
