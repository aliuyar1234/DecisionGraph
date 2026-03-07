defmodule Mix.Tasks.Dg.Accounts.Bootstrap do
  @shortdoc "Generates a self-hosted service-account bootstrap JSON file with rotate-friendly tokens"

  use Mix.Task

  @requirements ["loadpaths"]

  @admin_permissions [
    "projection_rebuild",
    "projection_replay",
    "workflow_assign",
    "workflow_escalate",
    "workflow_export",
    "workflow_override",
    "workflow_review"
  ]

  @impl true
  def run(args) do
    opts = parse_args!(args)
    payload = build_payload(opts)

    if output = Keyword.get(opts, :output) do
      output |> Path.dirname() |> File.mkdir_p!()
      File.write!(output, Jason.encode_to_iodata!(payload, pretty: true))
    end

    print_summary(payload, opts)
  end

  defp parse_args!(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          account_prefix: :string,
          include_release_demo: :boolean,
          output: :string,
          tenant_id: :string
        ],
        aliases: [o: :output]
      )

    if invalid != [] do
      raise ArgumentError, "Unsupported dg.accounts.bootstrap options: #{inspect(invalid)}"
    end

    [
      account_prefix: Keyword.get(opts, :account_prefix, "main"),
      include_release_demo: Keyword.get(opts, :include_release_demo, false),
      output: Keyword.get(opts, :output),
      tenant_id: Keyword.get(opts, :tenant_id, "default")
    ]
  end

  defp build_payload(opts) do
    tenant_ids =
      [Keyword.fetch!(opts, :tenant_id)]
      |> maybe_include_release_demo(Keyword.fetch!(opts, :include_release_demo))
      |> Enum.uniq()

    prefix = Keyword.fetch!(opts, :account_prefix)

    %{
      "generated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "operator_console_account_id" => "admin-#{prefix}",
      "service_accounts" => [
        %{
          "account_id" => "reader-#{prefix}",
          "permissions" => [],
          "roles" => ["reader"],
          "tenant_ids" => tenant_ids,
          "tokens" => [generate_token()]
        },
        %{
          "account_id" => "writer-#{prefix}",
          "permissions" => ["workflow_assign", "workflow_review"],
          "roles" => ["writer"],
          "tenant_ids" => tenant_ids,
          "tokens" => [generate_token()]
        },
        %{
          "account_id" => "admin-#{prefix}",
          "permissions" => @admin_permissions,
          "roles" => ["admin"],
          "tenant_ids" => tenant_ids,
          "tokens" => [generate_token()]
        }
      ]
    }
  end

  defp maybe_include_release_demo(tenant_ids, true), do: tenant_ids ++ ["release-demo"]
  defp maybe_include_release_demo(tenant_ids, false), do: tenant_ids

  defp generate_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp print_summary(payload, opts) do
    output_path = Keyword.get(opts, :output, "(stdout only)")

    lines =
      payload["service_accounts"]
      |> Enum.map_join("\n", fn account ->
        token = account["tokens"] |> List.first()
        "  #{account["account_id"]}: #{token}"
      end)

    IO.puts("""
    DecisionGraph service-account bootstrap generated
    output: #{output_path}
    operator_console_account_id: #{payload["operator_console_account_id"]}

    Tokens
    #{lines}

    Runtime
      DECISION_GRAPH_SERVICE_ACCOUNTS_FILE=#{Keyword.get(opts, :output, "/path/to/service-accounts.json")}
      DECISION_GRAPH_OPERATOR_ACCOUNT_ID=#{payload["operator_console_account_id"]}
    """)
  end
end
