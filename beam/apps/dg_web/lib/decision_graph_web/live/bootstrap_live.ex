defmodule DecisionGraphWeb.BootstrapLive do
  use DecisionGraphWeb, :live_view

  alias DecisionGraph.Api.Bootstrap

  @impl true
  def mount(_params, _session, socket) do
    status = Bootstrap.status_snapshot()
    rotation_account_id = List.first(Bootstrap.configured_account_ids())

    {:ok,
     socket
     |> assign(:page_title, "DecisionGraph Bootstrap Studio")
     |> assign(:status, status)
     |> assign(:bootstrap_form, default_bootstrap_form())
     |> assign(:bootstrap_preview, Bootstrap.generate_preview())
     |> assign(:rotation_form, %{"account_id" => rotation_account_id || ""})
     |> assign(:rotation_preview, rotation_preview_for(rotation_account_id))}
  end

  @impl true
  def handle_event("bootstrap_form_change", %{"bootstrap" => params}, socket) do
    form = bootstrap_form_from_params(params)

    {:noreply,
     socket
     |> assign(:bootstrap_form, form)
     |> assign(:bootstrap_preview, bootstrap_preview_for(form))}
  end

  @impl true
  def handle_event("rotation_form_change", %{"rotation" => params}, socket) do
    form = %{"account_id" => string_param(params, "account_id", "")}

    {:noreply,
     socket
     |> assign(:rotation_form, form)
     |> assign(:rotation_preview, rotation_preview_for(form["account_id"]))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="bootstrap-shell">
      <style>
        .bootstrap-shell {
          background:
            radial-gradient(circle at top left, rgba(31, 108, 99, 0.15), transparent 22rem),
            linear-gradient(180deg, #f5efe4 0%, #eef4f7 100%);
          color: #12313a;
          font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
          min-height: 100vh;
          padding: 2rem 1.25rem 3rem;
        }

        .bootstrap-frame {
          margin: 0 auto;
          max-width: 1180px;
        }

        .bootstrap-hero,
        .bootstrap-panel,
        .bootstrap-card {
          background: rgba(255, 252, 248, 0.94);
          border: 1px solid rgba(17, 49, 62, 0.08);
          border-radius: 24px;
          box-shadow: 0 18px 40px rgba(17, 49, 62, 0.08);
        }

        .bootstrap-hero,
        .bootstrap-panel {
          padding: 1.4rem;
        }

        .bootstrap-hero {
          display: grid;
          gap: 1rem;
          margin-bottom: 1rem;
        }

        .bootstrap-grid {
          display: grid;
          gap: 1rem;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        }

        .bootstrap-card {
          padding: 1rem;
        }

        .bootstrap-metrics {
          display: grid;
          gap: 1rem;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          margin-top: 1rem;
        }

        .bootstrap-panels {
          display: grid;
          gap: 1rem;
          margin-top: 1rem;
        }

        .bootstrap-panels h2,
        .bootstrap-card h3 {
          font-size: 0.92rem;
          letter-spacing: 0.08em;
          margin: 0 0 0.4rem;
          opacity: 0.7;
          text-transform: uppercase;
        }

        .helper-text {
          margin: 0.25rem 0 0;
          opacity: 0.72;
        }

        .mono {
          font-family: "IBM Plex Mono", Consolas, monospace;
        }

        .field-grid {
          display: grid;
          gap: 1rem;
          grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        }

        .field {
          display: grid;
          gap: 0.4rem;
        }

        .field label {
          font-size: 0.82rem;
          font-weight: 700;
          letter-spacing: 0.06em;
          opacity: 0.7;
          text-transform: uppercase;
        }

        .field input,
        .field select {
          border: 1px solid rgba(17, 49, 62, 0.14);
          border-radius: 14px;
          font: inherit;
          padding: 0.75rem 0.85rem;
        }

        .check-row {
          align-items: center;
          display: flex;
          gap: 0.6rem;
          margin-top: 1rem;
        }

        .payload-box {
          background: #11313e;
          border-radius: 18px;
          color: #f7f3ec;
          margin-top: 1rem;
          overflow-x: auto;
          padding: 1rem;
        }

        .payload-box pre {
          margin: 0;
          white-space: pre-wrap;
          word-break: break-word;
        }

        .account-grid {
          display: grid;
          gap: 0.85rem;
        }

        .note-list {
          display: grid;
          gap: 0.45rem;
          margin-top: 1rem;
        }

        .pill {
          align-items: center;
          background: rgba(31, 108, 99, 0.1);
          border-radius: 999px;
          display: inline-flex;
          font-size: 0.82rem;
          font-weight: 700;
          gap: 0.35rem;
          padding: 0.35rem 0.7rem;
        }

        a {
          color: #1f6c63;
        }
      </style>

      <div class="bootstrap-frame">
        <section class="bootstrap-hero">
          <div>
            <p class="helper-text">DecisionGraph self-hosted first-run and token-rotation helper</p>
            <h1>Bootstrap Studio</h1>
            <p class="helper-text">
              Generate a fresh service-account bootstrap preview, inspect the currently loaded auth state,
              and plan safe token overlap for rotation windows without hand-authoring JSON.
            </p>
          </div>

          <p class="helper-text">
            <a href="/">Back to operator console</a>
          </p>
        </section>

        <section class="bootstrap-panel">
          <h2>Current Runtime Auth State</h2>
          <div class="bootstrap-metrics">
            <article class="bootstrap-card">
              <h3>Bootstrap Source</h3>
              <p class="mono"><%= @status.bootstrap_source %></p>
            </article>
            <article class="bootstrap-card">
              <h3>Operator Account</h3>
              <p class="mono"><%= @status.operator_console_account_id || "not configured" %></p>
            </article>
            <article class="bootstrap-card">
              <h3>Configured Accounts</h3>
              <p><%= @status.configured_account_count %></p>
            </article>
          </div>

          <div class="account-grid" style="margin-top: 1rem;">
            <%= for account <- @status.service_accounts do %>
              <article class="bootstrap-card">
                <h3><%= account.account_id %></h3>
                <p class="helper-text">
                  roles <span class="mono"><%= Enum.join(account.roles, ", ") %></span> |
                  tenants <span class="mono"><%= Enum.join(account.tenant_ids, ", ") %></span> |
                  tokens <span class="mono"><%= account.token_count %></span>
                </p>
              </article>
            <% end %>
          </div>
        </section>

        <section class="bootstrap-panels">
          <section class="bootstrap-panel">
            <h2>Fresh Bootstrap Preview</h2>
            <form phx-change="bootstrap_form_change">
              <div class="field-grid">
                <div class="field">
                  <label for="bootstrap_account_prefix">Account Prefix</label>
                  <input
                    id="bootstrap_account_prefix"
                    name="bootstrap[account_prefix]"
                    type="text"
                    value={@bootstrap_form["account_prefix"]}
                  />
                </div>

                <div class="field">
                  <label for="bootstrap_tenant_id">Primary Tenant</label>
                  <input
                    id="bootstrap_tenant_id"
                    name="bootstrap[tenant_id]"
                    type="text"
                    value={@bootstrap_form["tenant_id"]}
                  />
                </div>
              </div>

              <label class="check-row" for="bootstrap_include_release_demo">
                <input
                  id="bootstrap_include_release_demo"
                  name="bootstrap[include_release_demo]"
                  type="checkbox"
                  value="true"
                  checked={@bootstrap_form["include_release_demo"] == "true"}
                />
                <span>Include the seeded <span class="mono">release-demo</span> tenant</span>
              </label>
            </form>

            <div class="bootstrap-metrics">
              <article class="bootstrap-card">
                <h3>Runtime Variable</h3>
                <p class="mono"><%= @bootstrap_preview.env["DECISION_GRAPH_SERVICE_ACCOUNTS_FILE"] %></p>
              </article>
              <article class="bootstrap-card">
                <h3>Operator Account</h3>
                <p class="mono"><%= @bootstrap_preview.env["DECISION_GRAPH_OPERATOR_ACCOUNT_ID"] %></p>
              </article>
            </div>

            <div class="payload-box">
              <pre><%= @bootstrap_preview.json %></pre>
            </div>
          </section>

          <section class="bootstrap-panel">
            <h2>Token Rotation Preview</h2>
            <form phx-change="rotation_form_change">
              <div class="field">
                <label for="rotation_account_id">Configured Account</label>
                <select id="rotation_account_id" name="rotation[account_id]">
                  <option value="">Select account</option>
                  <%= for account <- @status.service_accounts do %>
                    <option value={account.account_id} selected={@rotation_form["account_id"] == account.account_id}>
                      <%= account.account_id %>
                    </option>
                  <% end %>
                </select>
              </div>
            </form>

            <%= case @rotation_preview do %>
              <% {:ok, preview} -> %>
                <div class="payload-box">
                  <pre><%= preview.json %></pre>
                </div>

                <div class="note-list">
                  <%= for note <- preview.notes do %>
                    <span class="pill"><%= note %></span>
                  <% end %>
                </div>
              <% {:error, message} -> %>
                <p class="helper-text"><%= message %></p>
            <% end %>
          </section>
        </section>
      </div>
    </main>
    """
  end

  defp default_bootstrap_form do
    %{
      "account_prefix" => "main",
      "include_release_demo" => "false",
      "tenant_id" => "default"
    }
  end

  defp bootstrap_form_from_params(params) do
    %{
      "account_prefix" => string_param(params, "account_prefix", "main"),
      "include_release_demo" => checkbox_param(params, "include_release_demo"),
      "tenant_id" => string_param(params, "tenant_id", "default")
    }
  end

  defp bootstrap_preview_for(form) do
    Bootstrap.generate_preview(
      account_prefix: form["account_prefix"],
      include_release_demo: form["include_release_demo"] == "true",
      tenant_id: form["tenant_id"]
    )
  rescue
    error ->
      %{
        env: %{
          "DECISION_GRAPH_OPERATOR_ACCOUNT_ID" => "invalid",
          "DECISION_GRAPH_SERVICE_ACCOUNTS_FILE" => "/absolute/path/to/service-accounts.json"
        },
        json: Exception.message(error),
        payload: %{}
      }
  end

  defp rotation_preview_for(nil),
    do: {:error, "Select an account to preview a rotated token set."}

  defp rotation_preview_for(""), do: {:error, "Select an account to preview a rotated token set."}
  defp rotation_preview_for(account_id), do: Bootstrap.rotate_preview(account_id)

  defp string_param(params, key, default) do
    params
    |> Map.get(key, default)
    |> to_string()
    |> String.trim()
    |> case do
      "" -> default
      value -> value
    end
  end

  defp checkbox_param(params, key) do
    if Map.get(params, key) in ["true", "on"], do: "true", else: "false"
  end
end
