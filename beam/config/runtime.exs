import Config

decode_bootstrap_json! = fn raw, source ->
  case Jason.decode(raw) do
    {:ok, %{} = payload} ->
      payload

    {:ok, other} ->
      raise """
      DecisionGraph service-account bootstrap from #{source} must decode to a JSON object.
      Got: #{inspect(other)}
      """

    {:error, error} ->
      raise """
      DecisionGraph could not decode service-account bootstrap JSON from #{source}: #{Exception.message(error)}
      """
  end
end

ensure_service_accounts! = fn payload, source ->
  service_accounts =
    Map.get(payload, "service_accounts") ||
      Map.get(payload, :service_accounts) ||
      []

  if service_accounts == [] do
    raise """
    DecisionGraph bootstrap source #{source} did not include any service_accounts entries.
    """
  end

  service_accounts
end

infer_operator_console_account_id = fn service_accounts ->
  service_accounts
  |> Enum.find_value(fn account ->
    roles =
      Map.get(account, "roles") ||
        Map.get(account, :roles) ||
        []

    account_id =
      Map.get(account, "account_id") ||
        Map.get(account, :account_id)

    if "admin" in Enum.map(List.wrap(roles), &to_string/1), do: to_string(account_id)
  end)
end

deployment_env =
  System.get_env("DECISION_GRAPH_DEPLOYMENT_ENV") ||
    if(config_env() == :prod, do: "prod", else: Atom.to_string(config_env()))

config :dg_api, deployment_env: deployment_env

bootstrap =
  cond do
    raw = System.get_env("DECISION_GRAPH_SERVICE_ACCOUNTS_JSON") ->
      payload = decode_bootstrap_json!.(raw, "DECISION_GRAPH_SERVICE_ACCOUNTS_JSON")

      service_accounts =
        ensure_service_accounts!.(payload, "DECISION_GRAPH_SERVICE_ACCOUNTS_JSON")

      operator_console_account_id =
        System.get_env("DECISION_GRAPH_OPERATOR_ACCOUNT_ID") ||
          Map.get(payload, "operator_console_account_id") ||
          Map.get(payload, :operator_console_account_id) ||
          infer_operator_console_account_id.(service_accounts)

      if is_nil(operator_console_account_id) do
        raise """
        DecisionGraph could not infer operator_console_account_id from DECISION_GRAPH_SERVICE_ACCOUNTS_JSON.
        Set DECISION_GRAPH_OPERATOR_ACCOUNT_ID explicitly or include operator_console_account_id in the JSON payload.
        """
      end

      %{
        operator_console_account_id: operator_console_account_id,
        service_accounts: service_accounts,
        source: "env_json"
      }

    path =
        System.get_env("DECISION_GRAPH_SERVICE_ACCOUNTS_FILE") ||
          (case System.get_env("RELEASE_ROOT") do
             nil ->
               nil

             "" ->
               nil

             release_root ->
               candidate = Path.join([release_root, "config", "service-accounts.json"])
               if File.exists?(candidate), do: candidate
           end) ->
      payload =
        path
        |> File.read!()
        |> decode_bootstrap_json!.(path)

      service_accounts = ensure_service_accounts!.(payload, path)

      operator_console_account_id =
        System.get_env("DECISION_GRAPH_OPERATOR_ACCOUNT_ID") ||
          Map.get(payload, "operator_console_account_id") ||
          Map.get(payload, :operator_console_account_id) ||
          infer_operator_console_account_id.(service_accounts)

      if is_nil(operator_console_account_id) do
        raise """
        DecisionGraph could not infer operator_console_account_id from #{path}.
        Set DECISION_GRAPH_OPERATOR_ACCOUNT_ID explicitly or include operator_console_account_id in the JSON file.
        """
      end

      %{
        operator_console_account_id: operator_console_account_id,
        service_accounts: service_accounts,
        source: "file:" <> path
      }

    true ->
      %{
        operator_console_account_id: System.get_env("DECISION_GRAPH_OPERATOR_ACCOUNT_ID"),
        source: "application_env"
      }
  end

if operator_console_account_id = Map.get(bootstrap, :operator_console_account_id) do
  config :dg_api, operator_console_account_id: operator_console_account_id
end

if service_accounts = Map.get(bootstrap, :service_accounts) do
  config :dg_api, service_accounts: service_accounts
end

config :dg_api, bootstrap_source: Map.fetch!(bootstrap, :source)

enforce_bootstrap? =
  System.get_env("DECISION_GRAPH_VALIDATE_BOOTSTRAP") in ["1", "true", "TRUE"] or
    System.get_env("RELEASE_NAME") not in [nil, ""]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://decisiongraph:decisiongraph@localhost/decisiongraph_beam_prod"

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      "phase2-prod-secret-key-base"

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4100")
  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :dg_store, DecisionGraph.Store.Repo,
    url: database_url,
    pool_size: pool_size

  config :dg_store, start_repo: true

  config :dg_web, DecisionGraphWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: System.get_env("PHX_SERVER") in ["1", "true", "TRUE"],
    url: [host: host, port: 443, scheme: "https"]

  configured_service_accounts =
    Map.get(bootstrap, :service_accounts) ||
      Application.get_env(:dg_api, :service_accounts, [])

  if enforce_bootstrap? and configured_service_accounts == [] do
    raise """
    DecisionGraph production runtime requires service accounts.

    Provide one of:
    - DECISION_GRAPH_SERVICE_ACCOUNTS_FILE=/path/to/service-accounts.json
    - DECISION_GRAPH_SERVICE_ACCOUNTS_JSON='{"operator_console_account_id":"admin-main","service_accounts":[...]}'

    Or configure :dg_api, :service_accounts and :operator_console_account_id through your runtime config layer.
    """
  end
end
