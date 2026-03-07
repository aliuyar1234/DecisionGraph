defmodule DecisionGraphWeb.DashboardLive do
  use DecisionGraphWeb, :live_view

  @refresh_interval_ms 5_000
  @replay_projections ["trace_summary", "context_graph", "precedent_index", "all"]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval_ms)
    end

    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:page_title, "DecisionGraph Operator Console")
     |> assign(:refresh_interval_ms, @refresh_interval_ms)
     |> assign(:replay_form, default_replay_form())
     |> assign(:review_form, default_review_form())
     |> assign(:workflow_form, default_workflow_form())
     |> assign(:tenant_id, "default")
     |> assign(:trace_id, nil)
     |> assign(:workflow_id, nil)
     |> assign(:snapshot, snapshot_for("default", nil, nil))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tenant_id = normalize_param(Map.get(params, "tenant"), socket.assigns.tenant_id)
    trace_id = normalize_optional_param(Map.get(params, "trace_id"))
    workflow_id = normalize_optional_param(Map.get(params, "workflow_id"))

    {:noreply,
     socket
     |> assign(:tenant_id, tenant_id)
     |> assign(:trace_id, trace_id)
     |> assign(:workflow_id, workflow_id)
     |> assign(:loading, false)
     |> assign(:snapshot, snapshot_for(tenant_id, trace_id, workflow_id))}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, queue_snapshot_refresh(socket)}
  end

  @impl true
  def handle_event("replay_form_change", %{"replay" => params}, socket) do
    {:noreply,
     assign(socket, :replay_form, replay_form_from_params(params, socket.assigns.replay_form))}
  end

  @impl true
  def handle_event("workflow_form_change", %{"workflow" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :workflow_form,
       workflow_form_from_params(params, socket.assigns.workflow_form)
     )}
  end

  @impl true
  def handle_event("review_form_change", %{"review" => params}, socket) do
    {:noreply,
     assign(socket, :review_form, review_form_from_params(params, socket.assigns.review_form))}
  end

  @impl true
  def handle_event("start_replay", %{"replay" => params}, socket) do
    replay_form = replay_form_from_params(params, socket.assigns.replay_form)

    case validate_replay_form(replay_form, socket.assigns.snapshot) do
      :ok ->
        case DecisionGraph.Api.service(:console).start_replay(
               replay_request_attrs(replay_form, socket.assigns.trace_id),
               tenant_id: socket.assigns.tenant_id
             ) do
          {:ok, run} ->
            {:noreply,
             socket
             |> assign(:replay_form, reset_replay_form(replay_form))
             |> put_flash(:info, "Replay queued: #{run["job_id"]}")
             |> queue_snapshot_refresh()}

          {:error, error} ->
            {:noreply,
             socket
             |> assign(:replay_form, replay_form)
             |> put_flash(:error, error.message)}
        end

      {:error, message} ->
        {:noreply, socket |> assign(:replay_form, replay_form) |> put_flash(:error, message)}
    end
  end

  @impl true
  def handle_event("cancel_replay", %{"job_id" => job_id}, socket) do
    case DecisionGraph.Api.service(:console).cancel_replay(job_id,
           tenant_id: socket.assigns.tenant_id
         ) do
      {:ok, _run} ->
        {:noreply,
         socket
         |> put_flash(:info, "Replay cancelled: #{job_id}")
         |> queue_snapshot_refresh()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error.message)}
    end
  end

  @impl true
  def handle_event("submit_workflow_action", %{"workflow" => params}, socket) do
    workflow_form = workflow_form_from_params(params, socket.assigns.workflow_form)

    with {:ok, workflow_id} <- selected_workflow_id_result(socket.assigns.snapshot),
         :ok <- validate_workflow_form(workflow_form, socket.assigns.snapshot),
         {:ok, _result} <-
           DecisionGraph.Api.service(:console).act_on_workflow(
             workflow_id,
             workflow_request_attrs(workflow_form),
             tenant_id: socket.assigns.tenant_id
           ) do
      {:noreply,
       socket
       |> assign(:workflow_form, reset_workflow_form(workflow_form))
       |> put_flash(:info, "Workflow action recorded for #{workflow_id}")
       |> queue_snapshot_refresh()}
    else
      {:error, %{message: message}} ->
        {:noreply, socket |> assign(:workflow_form, workflow_form) |> put_flash(:error, message)}

      {:error, message} when is_binary(message) ->
        {:noreply, socket |> assign(:workflow_form, workflow_form) |> put_flash(:error, message)}
    end
  end

  @impl true
  def handle_event("start_trace_review", %{"review" => params}, socket) do
    review_form = review_form_from_params(params, socket.assigns.review_form)

    with {:ok, trace_id} <- selected_trace_id_result(socket.assigns.snapshot),
         :ok <- validate_review_form(review_form, socket.assigns.snapshot),
         {:ok, result} <-
           DecisionGraph.Api.service(:console).start_trace_review(
             trace_id,
             review_request_attrs(review_form),
             tenant_id: socket.assigns.tenant_id
           ) do
      message =
        if result["created"] in [true, "true"] do
          "Trace review started for #{trace_id}"
        else
          "Trace review already exists for #{trace_id}"
        end

      {:noreply,
       socket
       |> assign(:review_form, reset_review_form(review_form))
       |> put_flash(:info, message)
       |> queue_snapshot_refresh()}
    else
      {:error, %{message: message}} ->
        {:noreply, socket |> assign(:review_form, review_form) |> put_flash(:error, message)}

      {:error, message} when is_binary(message) ->
        {:noreply, socket |> assign(:review_form, review_form) |> put_flash(:error, message)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval_ms)
    {:noreply, queue_snapshot_refresh(socket)}
  end

  @impl true
  def handle_info({:load_snapshot, tenant_id, trace_id, workflow_id}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:snapshot, snapshot_for(tenant_id, trace_id, workflow_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="console-shell">
      <.console_styles />

      <div class="console-frame">
        <.hero_panel
          refresh_interval_ms={@refresh_interval_ms}
          snapshot={@snapshot}
          tenant_id={@tenant_id}
          trace_id={@trace_id}
          loading={@loading}
        />

        <.feedback_banners flash={@flash} loading={@loading} alerts={console_alerts(@snapshot)} />

        <.console_nav />

        <.summary_cards snapshot={@snapshot} />

        <.health_surface snapshot={@snapshot} tenant_id={@tenant_id} />

        <.workflow_surface
          workflow_form={@workflow_form}
          snapshot={@snapshot}
          tenant_id={@tenant_id}
        />

        <.review_studio_surface
          review_form={@review_form}
          snapshot={@snapshot}
          tenant_id={@tenant_id}
        />

        <.trace_and_policy_surface snapshot={@snapshot} tenant_id={@tenant_id} />

        <.graph_and_precedent_surface snapshot={@snapshot} tenant_id={@tenant_id} />

        <.replay_and_stream_surface
          replay_form={@replay_form}
          snapshot={@snapshot}
          tenant_id={@tenant_id}
          trace_id={@trace_id}
        />

        <.status_surface snapshot={@snapshot} />
      </div>
    </main>
    """
  end

  attr :loading, :boolean, required: true
  attr :refresh_interval_ms, :integer, required: true
  attr :snapshot, :map, required: true
  attr :tenant_id, :string, required: true
  attr :trace_id, :string, default: nil
  attr :workflow_form, :map, default: %{}

  defp hero_panel(assigns) do
    ~H"""
    <section class="hero">
      <div class="hero-copy">
        <p class="eyebrow">DecisionGraph Phase 7</p>
        <h1>Operator Console</h1>
        <p>
          Trace investigation, precedent review, replay safety, and live runtime posture now share one LiveView shell.
          Operators can move from health to trace context to replay actions without leaving the same screen.
        </p>
      </div>

      <div class="hero-side">
        <div class="hero-kicker">
          <span class="hero-chip">Tenant <%= @tenant_id %></span>
          <span class="hero-chip">Env <%= @snapshot.deployment_env %></span>
          <span class="hero-chip">Workers <%= @snapshot.projector["active_workers"] %></span>
          <span class="hero-chip">Actor <%= console_actor_label(@snapshot) %></span>
        </div>

        <div class="hero-meta">
          <div>
            <strong>Projection State</strong>
            <span class={["status-chip", projection_summary_tone(@snapshot)]}>
              <%= projection_summary_label(@snapshot) %>
            </span>
          </div>

          <div>
            <strong>Last Refresh</strong>
            <span><%= format_timestamp(@snapshot.refreshed_at) %></span>
          </div>

          <div>
            <strong>Selected Trace</strong>
            <span class="mono"><%= selected_trace_id(@snapshot) || "none" %></span>
          </div>
        </div>

        <div class="hero-actions">
          <span class="helper-text">
            <%= if @loading do %>
              Refreshing operator snapshot...
            <% else %>
              Auto-refresh every <%= div(@refresh_interval_ms, 1_000) %>s
            <% end %>
          </span>
          <button type="button" class="refresh-button" phx-click="refresh" disabled={@loading}>Refresh Snapshot</button>
        </div>
      </div>
    </section>
    """
  end

  attr :alerts, :list, required: true
  attr :flash, :map, required: true
  attr :loading, :boolean, required: true

  defp feedback_banners(assigns) do
    ~H"""
    <%= if @loading do %>
      <section class="banner">
        <strong>Refreshing operator console</strong>
        <p class="helper-text">The shell is pulling projection, replay, and trace state right now.</p>
      </section>
    <% end %>

    <%= if Phoenix.Flash.get(@flash, :info) do %>
      <section class="banner">
        <strong>Console update</strong>
        <p class="helper-text"><%= Phoenix.Flash.get(@flash, :info) %></p>
      </section>
    <% end %>

    <%= if Phoenix.Flash.get(@flash, :error) do %>
      <section class="alert-card alert-alert">
        <h3>Action failed</h3>
        <p><%= Phoenix.Flash.get(@flash, :error) %></p>
      </section>
    <% end %>

    <%= if @alerts != [] do %>
      <section class="alert-stack">
        <%= for alert <- @alerts do %>
          <article class={["alert-card", alert_tone(alert)]}>
            <h3><%= alert["title"] %></h3>
            <p><%= alert["detail"] %></p>
          </article>
        <% end %>
      </section>
    <% end %>
    """
  end

  defp console_nav(assigns) do
    ~H"""
    <nav class="subnav">
      <a href="#health">Health</a>
      <a href="#workflow">Workflow</a>
      <a href="#studio">Studio</a>
      <a href="#trace">Trace</a>
      <a href="#graph">Graph</a>
      <a href="#precedents">Precedents</a>
      <a href="#replay">Replay</a>
      <a href="#stream">Stream</a>
      <a href="#status">Status</a>
    </nav>
    """
  end

  attr :snapshot, :map, required: true

  defp summary_cards(assigns) do
    ~H"""
    <section class="summary-grid">
      <article class="metric-card">
        <h2>Pending Events</h2>
        <p><%= @snapshot.projection_health.summary.pending_events %></p>
        <span>Total lag remaining across tracked projections</span>
      </article>

      <article class="metric-card">
        <h2>Stale Projections</h2>
        <p><%= @snapshot.projection_health.summary.stale_count %></p>
        <span>Projection views still behind the event log</span>
      </article>

      <article class="metric-card">
        <h2>Open Replays</h2>
        <p><%= @snapshot.projection_health.summary.open_runs %></p>
        <span>Queued or running replay operations</span>
      </article>

      <article class="metric-card">
        <h2>Open Reviews</h2>
        <p><%= workflow_summary_metric(@snapshot, "open_count") %></p>
        <span>Workflow items waiting on human action</span>
      </article>

      <article class="metric-card">
        <h2>Overdue Reviews</h2>
        <p><%= workflow_summary_metric(@snapshot, "overdue_count") %></p>
        <span>Items that have crossed their SLA timer</span>
      </article>

      <article class="metric-card">
        <h2>Open Failures</h2>
        <p><%= @snapshot.projection_health.summary.open_failures %></p>
        <span>Terminal projector failures requiring operator review</span>
      </article>

      <article class="metric-card">
        <h2>Tracked Traces</h2>
        <p><%= tenant_metric(@snapshot, "trace_count") %></p>
        <span><%= tenant_metric(@snapshot, "active_trace_count") %> active in this tenant</span>
      </article>

      <article class="metric-card">
        <h2>Event Volume</h2>
        <p><%= tenant_metric(@snapshot, "event_count") %></p>
        <span>Append-only events recorded for this tenant</span>
      </article>
    </section>
    """
  end

  attr :snapshot, :map, required: true
  attr :tenant_id, :string, required: true

  defp health_surface(assigns) do
    ~H"""
    <section id="health" class="console-grid">
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2>Projection Health Dashboard</h2>
            <p>Lag, digests, replay queue state, and projection failure pressure for the active tenant.</p>
          </div>

          <span class={["status-chip", projection_summary_tone(@snapshot)]}>
            <%= projection_summary_label(@snapshot) %>
          </span>
        </div>

        <%= if section_ready?(@snapshot.projection_health) do %>
          <table class="health-table">
            <thead>
              <tr>
                <th>Projection</th>
                <th>Cursor</th>
                <th>Pending</th>
                <th>Digest</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for projection <- projection_rows(@snapshot) do %>
                <tr>
                  <td>
                    <strong><%= projection["projection_name"] %></strong>
                    <div class="helper-text">open failures: <%= projection["open_failures"] %></div>
                  </td>
                  <td class="mono"><%= projection["last_log_seq"] %></td>
                  <td><%= projection["pending_events"] %></td>
                  <td class="mono"><%= short_digest(projection["digest"]) %></td>
                  <td>
                    <span class={["status-chip", projection_status_tone(projection)]}>
                      <%= projection_status_label(projection) %>
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% else %>
          <div class="empty-state">
            <h3>Projection health unavailable</h3>
            <p><%= @snapshot.projection_health.error %></p>
          </div>
        <% end %>
      </div>

      <div class="sidebar-stack">
        <section class="panel">
          <div class="panel-header">
            <div>
              <h2>Recent Traces</h2>
              <p>Fast entry points into the latest projection-backed trace summaries for this tenant.</p>
            </div>

            <span class="status-chip status-neutral"><%= length(recent_traces(@snapshot)) %> loaded</span>
          </div>

          <%= if section_ready?(@snapshot.recent_traces) and recent_traces(@snapshot) != [] do %>
            <div class="graph-list">
              <%= for trace <- recent_traces(@snapshot) do %>
                <.link
                  patch={"/?tenant=#{@tenant_id}&trace_id=#{trace["trace_id"]}"}
                  class={["trace-link", trace_selected?(@snapshot, trace["trace_id"]) && "is-selected"]}
                >
                  <div class="trace-link-header">
                    <div>
                      <strong><%= trace["title"] || trace["workflow"] || trace["trace_id"] %></strong>
                      <p class="helper-text mono"><%= trace["trace_id"] %></p>
                    </div>

                    <span class={["status-chip", trace_state_tone(trace["status"])]}>
                      <%= trace["status"] %>
                    </span>
                  </div>

                  <div class="trace-summary-grid">
                    <article>
                      <strong>Workflow</strong>
                      <span><%= trace["workflow"] || "unknown" %></span>
                    </article>
                    <article>
                      <strong>Events</strong>
                      <span><%= trace["event_count"] %></span>
                    </article>
                    <article>
                      <strong>Last Log Seq</strong>
                      <span><%= trace["last_log_seq"] %></span>
                    </article>
                  </div>
                </.link>
              <% end %>
            </div>
          <% else %>
            <div class="empty-state">
              <h3>No recent traces available</h3>
              <p><%= @snapshot.recent_traces.error || "Trace summaries will appear here once the projector materializes them." %></p>
            </div>
          <% end %>
        </section>
      </div>
    </section>
    """
  end

  attr :snapshot, :map, required: true
  attr :tenant_id, :string, required: true
  attr :workflow_form, :map, required: true

  defp workflow_surface(assigns) do
    ~H"""
    <section id="workflow" class="panel-grid">
      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Workflow Inbox</h2>
            <p>Approval queues, SLA pressure, and assignment state for human review items.</p>
          </div>

          <span class="status-chip status-neutral">
            <%= workflow_summary_metric(@snapshot, "open_count") %> open
          </span>
        </div>

        <%= if section_ready?(@snapshot.workflow_inbox) and workflow_inbox_items(@snapshot) != [] do %>
          <div class="graph-list">
            <%= for workflow <- workflow_inbox_items(@snapshot) do %>
              <.link
                patch={
                  "/?tenant=#{@tenant_id}&trace_id=#{workflow["trace_id"]}&workflow_id=#{workflow["workflow_id"]}"
                }
                class={["trace-link", workflow_selected?(@snapshot, workflow["workflow_id"]) && "is-selected"]}
              >
                <div class="trace-link-header">
                  <div>
                    <strong><%= workflow["title"] || workflow["workflow_id"] %></strong>
                    <p class="helper-text mono"><%= workflow["workflow_id"] %></p>
                  </div>

                  <span class={["status-chip", workflow_status_tone(workflow["status"], workflow["overdue"])]}>
                    <%= workflow["status"] %>
                  </span>
                </div>

                <div class="trace-summary-grid">
                  <article>
                    <strong>Priority</strong>
                    <span><%= workflow["priority"] %></span>
                  </article>
                  <article>
                    <strong>Assignee</strong>
                    <span class="mono"><%= workflow_assignee_label(workflow) %></span>
                  </article>
                  <article>
                    <strong>SLA</strong>
                    <span><%= workflow["sla_due_at"] |> workflow_due_label(workflow["overdue"]) %></span>
                  </article>
                </div>
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="empty-state">
            <h3>No workflow items available</h3>
            <p><%= @snapshot.workflow_inbox.error || "Exception review items will appear here when approvals are requested." %></p>
          </div>
        <% end %>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Workflow Detail</h2>
            <p>Assignment, rationale, comment history, and action controls for the selected review item.</p>
          </div>

          <%= if selected_workflow_id(@snapshot) do %>
            <span class="status-chip status-neutral mono"><%= selected_workflow_id(@snapshot) %></span>
          <% end %>
        </div>

        <%= case @snapshot.selected_workflow.status do %>
          <% "ready" -> %>
            <% workflow = selected_workflow_item(@snapshot) %>
            <div class="metric-grid">
              <article class="detail-card">
                <span class="metric-label">Status</span>
                <strong><%= workflow["status"] %></strong>
              </article>
              <article class="detail-card">
                <span class="metric-label">Priority</span>
                <strong><%= workflow["priority"] %></strong>
              </article>
              <article class="detail-card">
                <span class="metric-label">Assignee</span>
                <strong class="mono"><%= workflow_assignee_label(workflow) %></strong>
              </article>
              <article class="detail-card">
                <span class="metric-label">Subject</span>
                <strong class="mono"><%= workflow_subject_label(workflow) %></strong>
              </article>
            </div>

            <div class="trace-summary-grid" style="margin-top: 1rem;">
              <article class="detail-card">
                <strong>Trace</strong>
                <span class="mono"><%= workflow["trace_id"] %></span>
              </article>
              <article class="detail-card">
                <strong>Requested</strong>
                <span><%= format_timestamp(workflow["requested_at"]) %></span>
              </article>
              <article class="detail-card">
                <strong>SLA Due</strong>
                <span><%= workflow["sla_due_at"] |> workflow_due_label(workflow["overdue"]) %></span>
              </article>
              <article class="detail-card">
                <strong>Current Decision</strong>
                <span><%= workflow["current_decision"] || "pending" %></span>
              </article>
            </div>

            <div class="payload-box" style="margin-top: 1rem;">
              <pre><%= pretty_json(workflow["metadata"]) %></pre>
            </div>

            <%= if workflow_review_context(@snapshot) do %>
              <% review_context = workflow_review_context(@snapshot) %>
              <% recommended_replay = review_context["recommended_replay"] || %{} %>
              <div class="trace-summary-grid" style="margin-top: 1rem;">
                <article class="detail-card">
                  <strong>Recommended Replay</strong>
                  <span>
                    <%= recommended_replay["mode"] || "pending" %> /
                    <%= recommended_replay["projection"] || "pending" %>
                  </span>
                </article>
                <article class="detail-card">
                  <strong>Precedent Preview</strong>
                  <span><%= length(review_context["precedent_preview"] || []) %> traces</span>
                </article>
                <article class="detail-card">
                  <strong>Suggested Templates</strong>
                  <span><%= length(review_context["templates"] || []) %> templates</span>
                </article>
                <article class="detail-card">
                  <strong>Simulation Priority</strong>
                  <span><%= review_context["simulation"]["priority"] || "pending" %></span>
                </article>
              </div>
            <% end %>

            <%= if workflow_actions_enabled?(@snapshot) do %>
              <form phx-change="workflow_form_change" phx-submit="submit_workflow_action" style="margin-top: 1rem;">
                <div class="metric-grid">
                  <label class="field">
                    <span>Action</span>
                    <select id="workflow_action" name="workflow[action]">
                      <%= for action <- workflow_action_options(@snapshot) do %>
                        <option value={action} selected={workflow_form_value(@workflow_form, "action") == action}>
                          <%= action %>
                        </option>
                      <% end %>
                    </select>
                  </label>

                  <label class="field">
                    <span>Assign Account</span>
                    <input
                      id="workflow_assigned_account_id"
                      name="workflow[assigned_account_id]"
                      type="text"
                      value={workflow_form_value(@workflow_form, "assigned_account_id")}
                    />
                  </label>

                  <label class="field">
                    <span>Assign Role</span>
                    <input
                      id="workflow_assigned_role"
                      name="workflow[assigned_role]"
                      type="text"
                      value={workflow_form_value(@workflow_form, "assigned_role")}
                    />
                  </label>

                  <label class="field">
                    <span>Override Confirm</span>
                    <input
                      id="workflow_confirm_text"
                      name="workflow[confirm_text]"
                      type="text"
                      value={workflow_form_value(@workflow_form, "confirm_text")}
                    />
                  </label>
                </div>

                <div class="metric-grid" style="margin-top: 1rem;">
                  <label class="field">
                    <span>Reason</span>
                    <textarea id="workflow_reason" name="workflow[reason]"><%= workflow_form_value(@workflow_form, "reason") %></textarea>
                  </label>

                  <label class="field">
                    <span>Note</span>
                    <textarea id="workflow_note" name="workflow[note]"><%= workflow_form_value(@workflow_form, "note") %></textarea>
                  </label>
                </div>

                <p class="helper-text">
                  Override confirmation phrase:
                  <span class="mono"><%= workflow_override_confirmation_phrase(workflow) %></span>
                </p>

                <button type="submit" class="refresh-button">Apply Workflow Action</button>
              </form>
            <% else %>
              <div class="empty-state" style="margin-top: 1rem;">
                <h3>Workflow actions disabled</h3>
                <p>The configured console actor does not have workflow review permissions.</p>
              </div>
            <% end %>

            <div class="graph-list" style="margin-top: 1rem;">
              <%= for action <- workflow_actions(@snapshot) do %>
                <article class="run-card">
                  <div class="trace-link-header">
                    <div>
                      <strong><%= action["action_type"] %></strong>
                      <p class="helper-text mono"><%= action["action_id"] %></p>
                    </div>

                    <span class={["status-chip", workflow_status_tone(action["resulting_status"], false)]}>
                      <%= action["resulting_status"] || "recorded" %>
                    </span>
                  </div>

                  <div class="trace-summary-grid" style="margin-top: 0.85rem;">
                    <article class="detail-card">
                      <strong>When</strong>
                      <span><%= format_timestamp(action["created_at"]) %></span>
                    </article>
                    <article class="detail-card">
                      <strong>Actor</strong>
                      <span class="mono"><%= workflow_action_actor_label(action) %></span>
                    </article>
                  </div>

                  <%= if action["note"] do %>
                    <p class="helper-text" style="margin-top: 0.85rem;"><%= action["note"] %></p>
                  <% end %>
                </article>
              <% end %>
            </div>

            <%= if workflow_notifications(@snapshot) != [] do %>
              <div class="graph-list" style="margin-top: 1rem;">
                <%= for notification <- workflow_notifications(@snapshot) do %>
                  <article class="run-card">
                    <div class="trace-link-header">
                      <div>
                        <strong><%= notification["category"] %></strong>
                        <p class="helper-text mono"><%= notification["notification_id"] %></p>
                      </div>

                      <span class="status-chip status-neutral"><%= notification["status"] %></span>
                    </div>

                    <p class="helper-text" style="margin-top: 0.85rem;"><%= notification["message"] %></p>
                  </article>
                <% end %>
              </div>
            <% end %>

          <% "unavailable" -> %>
            <div class="empty-state">
              <h3>Workflow detail unavailable</h3>
              <p><%= @snapshot.selected_workflow.error %></p>
            </div>

          <% _other -> %>
            <div class="empty-state">
              <h3>Select a workflow item</h3>
              <p><%= @snapshot.selected_workflow.error %></p>
            </div>
        <% end %>
      </section>
    </section>
    """
  end

  attr :snapshot, :map, required: true
  attr :review_form, :map, required: true
  attr :tenant_id, :string, required: true

  defp review_studio_surface(assigns) do
    ~H"""
    <section id="studio" class="panel-grid">
      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Workflow Studio and Incident Review</h2>
            <p>Dry-run template selection, review-start actions, and replay guidance for the selected trace.</p>
          </div>

          <%= if selected_trace_id(@snapshot) do %>
            <span class="status-chip status-neutral mono"><%= selected_trace_id(@snapshot) %></span>
          <% end %>
        </div>

        <%= case @snapshot.review_studio.status do %>
          <% "ready" -> %>
            <div class="summary-grid">
              <%= for template <- review_studio_templates(@snapshot) do %>
                <article class="metric-card">
                  <h2><%= template["title"] %></h2>
                  <p><%= template["reviewer_role"] %></p>
                  <span><%= template["default_sla_hours"] %>h SLA</span>
                </article>
              <% end %>
            </div>

            <div class="trace-summary-grid" style="margin-top: 1rem;">
              <article class="detail-card">
                <strong>Recommended Template</strong>
                <span><%= review_studio_template(@snapshot)["title"] %></span>
              </article>
              <article class="detail-card">
                <strong>Priority</strong>
                <span><%= review_studio_simulation(@snapshot)["priority"] %></span>
              </article>
              <article class="detail-card">
                <strong>Risk Signals</strong>
                <span><%= Enum.join(review_studio_simulation(@snapshot)["risk_signals"] || [], ", ") %></span>
              </article>
              <article class="detail-card">
                <strong>Existing Reviews</strong>
                <span><%= length(review_studio_existing_workflows(@snapshot)) %></span>
              </article>
            </div>

            <form phx-change="review_form_change" phx-submit="start_trace_review" style="margin-top: 1rem;">
              <div class="metric-grid">
                <label class="field">
                  <span>Template</span>
                  <select id="review_template_id" name="review[template_id]">
                    <%= for template <- review_studio_templates(@snapshot) do %>
                      <option value={template["template_id"]} selected={review_form_value(@review_form, "template_id") == template["template_id"]}>
                        <%= template["title"] %>
                      </option>
                    <% end %>
                  </select>
                </label>

                <label class="field">
                  <span>Reason</span>
                  <textarea id="review_reason" name="review[reason]"><%= review_form_value(@review_form, "reason") %></textarea>
                </label>
              </div>

              <button type="submit" class="refresh-button">Start Trace Review</button>
            </form>
          <% _other -> %>
            <div class="empty-state">
              <h3>Workflow studio unavailable</h3>
              <p><%= @snapshot.review_studio.error %></p>
            </div>
        <% end %>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Incident Review Journey</h2>
            <p>Replay posture, precedent carryover, and current review items connected to this trace.</p>
          </div>
        </div>

        <%= if section_ready?(@snapshot.review_studio) do %>
          <div class="trace-summary-grid">
            <article class="detail-card">
              <strong>Replay Suggestion</strong>
              <span>
                <%= review_studio_replay(@snapshot)["mode"] %> /
                <%= review_studio_replay(@snapshot)["projection"] %>
              </span>
            </article>
            <article class="detail-card">
              <strong>Replay Reason</strong>
              <span><%= review_studio_replay(@snapshot)["reason"] %></span>
            </article>
            <article class="detail-card">
              <strong>Precedent Preview</strong>
              <span><%= length(review_studio_precedents(@snapshot)) %></span>
            </article>
            <article class="detail-card">
              <strong>Workflow Draft</strong>
              <span class="mono"><%= review_studio_draft(@snapshot)["workflow_id"] %></span>
            </article>
          </div>

          <div class="graph-list" style="margin-top: 1rem;">
            <%= for workflow <- review_studio_existing_workflows(@snapshot) do %>
              <.link
                patch={
                  "/?tenant=#{@tenant_id}&trace_id=#{workflow["trace_id"]}&workflow_id=#{workflow["workflow_id"]}"
                }
                class="trace-link"
              >
                <div class="trace-link-header">
                  <div>
                    <strong><%= workflow["title"] || workflow["workflow_id"] %></strong>
                    <p class="helper-text mono"><%= workflow["workflow_id"] %></p>
                  </div>
                  <span class={["status-chip", workflow_status_tone(workflow["status"], workflow["overdue"])]}>
                    <%= workflow["status"] %>
                  </span>
                </div>
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="empty-state">
            <h3>Select a trace first</h3>
            <p>The workflow studio needs an active trace selection before it can draft or start review items.</p>
          </div>
        <% end %>
      </section>
    </section>
    """
  end

  attr :snapshot, :map, required: true
  attr :tenant_id, :string, required: true

  defp trace_and_policy_surface(assigns) do
    ~H"""
    <section id="trace" class="panel-grid">
      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Trace Explorer</h2>
            <p>Timeline and payload inspection for the selected decision trace.</p>
          </div>

          <%= if selected_trace_id(@snapshot) do %>
            <span class="status-chip status-neutral mono"><%= selected_trace_id(@snapshot) %></span>
          <% end %>
        </div>

        <%= case @snapshot.selected_trace.status do %>
          <% "ready" -> %>
            <% summary = selected_trace_summary(@snapshot) %>
            <div class="trace-summary-grid">
              <article class="detail-card">
                <strong>Workflow</strong>
                <span><%= summary["workflow"] || "unknown" %></span>
              </article>
              <article class="detail-card">
                <strong>Outcome</strong>
                <span><%= summary["outcome"] || "pending" %></span>
              </article>
              <article class="detail-card">
                <strong>Events</strong>
                <span><%= summary["event_count"] || length(selected_trace_events(@snapshot)) %></span>
              </article>
              <article class="detail-card">
                <strong>Primary Entity</strong>
                <span class="mono"><%= entity_label(summary) %></span>
              </article>
            </div>

            <details style="margin-top: 1rem;">
              <summary><strong>Investigator Handoff</strong></summary>
              <div class="payload-box">
                <pre><%= trace_handoff(@snapshot) %></pre>
              </div>
            </details>

            <div class="trace-events" style="margin-top: 1rem;">
              <%= for event <- selected_trace_events(@snapshot) do %>
                <article class="event-card">
                  <div class="event-header">
                    <div style="display: flex; align-items: center; gap: 0.75rem;">
                      <span class="event-seq">#<%= event["trace_seq"] %></span>
                      <div>
                        <strong><%= event["event_type"] %></strong>
                        <span class="helper-text mono"><%= event["event_id"] %></span>
                      </div>
                    </div>

                    <span class={["status-chip", event_state_tone(event["event_type"])]}>
                      <%= event["event_type"] %>
                    </span>
                  </div>

                  <div class="event-facts" style="margin-top: 0.85rem;">
                    <div>
                      <strong>Occurred At</strong>
                      <span><%= format_timestamp(event["occurred_at"]) %></span>
                    </div>
                    <div>
                      <strong>Actor</strong>
                      <span class="mono"><%= actor_label(event["actor"]) %></span>
                    </div>
                    <div>
                      <strong>Trace</strong>
                      <span class="mono"><%= event["trace_id"] %></span>
                    </div>
                  </div>

                  <details style="margin-top: 0.9rem;">
                    <summary><strong>Payload Inspection</strong></summary>
                    <div class="payload-box">
                      <pre><%= pretty_json(event["payload"]) %></pre>
                    </div>
                  </details>
                </article>
              <% end %>
            </div>

          <% "unavailable" -> %>
            <div class="empty-state">
              <h3>Trace explorer unavailable</h3>
              <p><%= @snapshot.selected_trace.error %></p>
            </div>

          <% _other -> %>
            <div class="empty-state">
              <h3>Select a trace</h3>
              <p><%= @snapshot.selected_trace.error %></p>
            </div>
        <% end %>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Policy and Exception Review</h2>
            <p>Decision basis, exception posture, approval, and action commit state for the selected trace.</p>
          </div>
        </div>

        <%= if section_ready?(@snapshot.policy_review) do %>
          <% policy = policy_review_data(@snapshot)["policy"] || %{} %>
          <% exception = policy_review_data(@snapshot)["exception"] || %{} %>
          <% approval = policy_review_data(@snapshot)["approval"] || %{} %>
          <% action = policy_review_data(@snapshot)["action"] || %{} %>

          <div class="metric-grid">
            <article class="detail-card">
              <span class="metric-label">Policy</span>
              <strong><%= policy_label(policy) %></strong>
              <p class="helper-text"><%= policy["decision"] || "pending" %></p>
            </article>
            <article class="detail-card">
              <span class="metric-label">Exception</span>
              <strong><%= exception["exception_id"] || "not required" %></strong>
              <p class="helper-text"><%= exception["status"] || "pending" %></p>
            </article>
            <article class="detail-card">
              <span class="metric-label">Approval</span>
              <strong><%= approval["decision"] || "pending" %></strong>
              <p class="helper-text mono"><%= actor_label(approval["actor"]) %></p>
            </article>
            <article class="detail-card">
              <span class="metric-label">Action</span>
              <strong><%= action["status"] || "pending" %></strong>
              <p class="helper-text mono"><%= action["action_id"] || "pending" %></p>
            </article>
          </div>

          <div class="graph-list" style="margin-top: 1rem;">
            <%= for item <- policy_timeline(@snapshot) do %>
              <article class="run-card">
                <div class="trace-link-header">
                  <div>
                    <strong><%= item["event_type"] %></strong>
                    <p class="helper-text mono"><%= item["event_id"] %></p>
                  </div>

                  <span class={["status-chip", event_state_tone(item["event_type"])]}>
                    <%= item["summary"] %>
                  </span>
                </div>

                <div class="trace-summary-grid" style="margin-top: 0.85rem;">
                  <article class="detail-card">
                    <strong>Occurred</strong>
                    <span><%= format_timestamp(item["occurred_at"]) %></span>
                  </article>
                  <article class="detail-card">
                    <strong>Actor</strong>
                    <span class="mono"><%= actor_label(item["actor"]) %></span>
                  </article>
                </div>
              </article>
            <% end %>
          </div>
        <% else %>
          <div class="empty-state">
            <h3>Policy review unavailable</h3>
            <p><%= @snapshot.policy_review.error %></p>
          </div>
        <% end %>
      </section>
    </section>
    """
  end

  attr :snapshot, :map, required: true
  attr :tenant_id, :string, required: true

  defp graph_and_precedent_surface(assigns) do
    ~H"""
    <section class="panel-grid">
      <section id="graph" class="panel">
        <div class="panel-header">
          <div>
            <h2>Context Graph Visualizer</h2>
            <p>Trace-centered graph context for policy, exception, action, and precedent relationships.</p>
          </div>
        </div>

        <%= cond do %>
          <% section_ready?(@snapshot.context_graph) -> %>
            <div class="chip-row" style="margin-bottom: 1rem;">
              <span class="hero-chip mono"><%= graph_data(@snapshot)["center_trace_id"] %></span>
              <span class="hero-chip"><%= graph_data(@snapshot)["node_count"] %> nodes</span>
              <span class="hero-chip"><%= graph_data(@snapshot)["edge_count"] %> edges</span>
              <span class="hero-chip"><%= if graph_data(@snapshot)["truncated"], do: "truncated", else: "complete" %></span>
            </div>

            <div class="graph-list">
              <%= for node <- graph_nodes(@snapshot) do %>
                <article class="detail-card">
                  <strong><%= node["node_type"] %></strong>
                  <p class="helper-text mono"><%= node["node_id"] %></p>
                </article>
              <% end %>
            </div>

            <div class="graph-list" style="margin-top: 1rem;">
              <%= for edge <- graph_edges(@snapshot) do %>
                <article class="run-card">
                  <strong><%= edge["edge_type"] %></strong>
                  <p class="helper-text mono"><%= edge["from_node_id"] %> -> <%= edge["to_node_id"] %></p>
                </article>
              <% end %>
            </div>

          <% @snapshot.context_graph.status == "empty" -> %>
            <div class="empty-state">
              <h3>Pick a trace to render graph context</h3>
              <p><%= @snapshot.context_graph.error %></p>
            </div>

          <% true -> %>
            <div class="empty-state">
              <h3>Context graph unavailable</h3>
              <p><%= @snapshot.context_graph.error %></p>
            </div>
        <% end %>
      </section>

      <section id="precedents" class="panel">
        <div class="panel-header">
          <div>
            <h2>Precedent Browser and Comparison</h2>
            <p>Similar cases, outcome deltas, and quick links back into historical traces.</p>
          </div>
        </div>

        <%= cond do %>
          <% section_ready?(@snapshot.precedents) -> %>
            <% focus = precedent_focus(@snapshot) %>
            <div class="chip-row" style="margin-bottom: 1rem;">
              <span class="hero-chip mono"><%= focus["trace_id"] %></span>
              <span class="hero-chip"><%= focus["entity_type"] %>:<%= focus["entity_id"] %></span>
              <span class="hero-chip"><%= focus["outcome"] || "pending" %></span>
            </div>

            <div class="precedent-list">
              <%= for precedent <- precedent_items(@snapshot) do %>
                <article class="run-card">
                  <div class="trace-link-header">
                    <div>
                      <strong><%= precedent["title"] || precedent["workflow"] || precedent["trace_id"] %></strong>
                      <p class="helper-text mono"><%= precedent["trace_id"] %></p>
                    </div>

                    <span class={["status-chip", trace_state_tone(precedent["outcome"])]}>
                      <%= precedent["outcome"] || "finished" %>
                    </span>
                  </div>

                  <div class="trace-summary-grid" style="margin-top: 0.85rem;">
                    <article class="detail-card">
                      <strong>Outcome Delta</strong>
                      <span><%= precedent_outcome_delta(@snapshot, precedent) %></span>
                    </article>
                    <article class="detail-card">
                      <strong>Policy Lineage</strong>
                      <span><%= precedent_policy_label(precedent) %></span>
                    </article>
                    <article class="detail-card">
                      <strong>Finished</strong>
                      <span><%= format_timestamp(precedent["finished_at"]) %></span>
                    </article>
                  </div>

                  <div class="button-row" style="margin-top: 0.85rem;">
                    <.link patch={"/?tenant=#{@tenant_id}&trace_id=#{precedent["trace_id"]}"} class="ghost-button">
                      Open Trace
                    </.link>
                  </div>
                </article>
              <% end %>
            </div>

          <% @snapshot.precedents.status == "empty" -> %>
            <div class="empty-state">
              <h3>No matching precedents</h3>
              <p><%= @snapshot.precedents.error %></p>
            </div>

          <% true -> %>
            <div class="empty-state">
              <h3>Precedent browser unavailable</h3>
              <p><%= @snapshot.precedents.error %></p>
            </div>
        <% end %>
      </section>
    </section>
    """
  end

  attr :replay_form, :map, required: true
  attr :snapshot, :map, required: true
  attr :tenant_id, :string, required: true
  attr :trace_id, :string, default: nil

  defp replay_and_stream_surface(assigns) do
    ~H"""
    <section class="panel-grid">
      <section id="replay" class="panel">
        <div class="panel-header">
          <div>
            <h2>Replay Console</h2>
            <p>Safe replay controls, digest alignment, and projector failure recovery hints.</p>
          </div>
        </div>

        <div class="detail-card">
          <strong>Replay Request</strong>
          <p class="helper-text">
            Actions execute as <span class="mono"><%= console_actor_label(@snapshot) %></span>. Type the exact confirmation phrase before queueing replay work.
          </p>
          <form phx-change="replay_form_change" phx-submit="start_replay" style="margin-top: 1rem;">
            <div class="trace-summary-grid">
              <div class="field">
                <label for="replay_projection">Projection</label>
                <select id="replay_projection" name="replay[projection]">
                  <%= for projection <- replay_projection_options() do %>
                    <option value={projection} selected={replay_form_value(@replay_form, "projection") == projection}>
                      <%= projection %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div class="field">
                <label for="replay_mode">Mode</label>
                <select id="replay_mode" name="replay[mode]">
                  <option value="catch_up" selected={replay_form_value(@replay_form, "mode") == "catch_up"}>catch_up</option>
                  <option value="rebuild" selected={replay_form_value(@replay_form, "mode") == "rebuild"} disabled={!console_can_rebuild?(@snapshot)}>
                    rebuild
                  </option>
                </select>
              </div>
            </div>

            <div class="field" style="margin-top: 1rem;">
              <label for="replay_reason">Reason</label>
              <textarea id="replay_reason" name="replay[reason]"><%= replay_form_value(@replay_form, "reason") %></textarea>
            </div>

            <div class="field" style="margin-top: 1rem;">
              <label for="replay_confirm">
                Typed confirmation: <span class="mono"><%= replay_confirmation_phrase(@replay_form) %></span>
              </label>
              <input
                id="replay_confirm"
                type="text"
                name="replay[confirm_text]"
                value={replay_form_value(@replay_form, "confirm_text")}
              />
            </div>

              <div class="button-row" style="margin-top: 1rem;">
                <button type="submit" class="primary-button" disabled={!console_actions_enabled?(@snapshot)}>Queue Replay</button>
              </div>
            </form>
          </div>

          <div class="metric-grid" style="margin-top: 1rem;">
            <article class="detail-card">
              <span class="metric-label">Full Projection Digest</span>
              <strong class="mono"><%= short_digest(replay_full_digest(@snapshot)) %></strong>
            </article>

            <%= for digest <- replay_digest_rows(@snapshot) do %>
              <article class="detail-card">
                <span class="metric-label"><%= digest["projection_name"] %></span>
                <strong class="mono"><%= short_digest(digest["digest"]) %></strong>
                <p class="helper-text">
                  cursor <%= digest["last_log_seq"] %> /
                  <span class={["status-chip", digest_alignment_tone(@snapshot, digest)]}>
                    <%= digest_alignment_label(@snapshot, digest) %>
                  </span>
                </p>
              </article>
            <% end %>
          </div>

          <div class="run-list" style="margin-top: 1rem;">
            <%= for run <- replay_runs(@snapshot) do %>
              <article class="run-card">
                <div class="trace-link-header">
                  <div>
                    <strong><%= run["projection_name"] %></strong>
                    <p class="helper-text mono"><%= run["job_id"] %></p>
                  </div>

                  <span class={["status-chip", replay_status_tone(run["status"])]}>
                    <%= run["status"] %>
                  </span>
                </div>

                <div class="trace-summary-grid" style="margin-top: 0.85rem;">
                  <article class="detail-card">
                    <strong>Mode</strong>
                    <span><%= run["mode"] %></span>
                  </article>
                  <article class="detail-card">
                    <strong>Processed</strong>
                    <span><%= run["processed_events"] || 0 %></span>
                  </article>
                  <article class="detail-card">
                    <strong>Cursor</strong>
                    <span><%= run["last_log_seq"] || 0 %></span>
                  </article>
                  <article class="detail-card">
                    <strong>Finished</strong>
                    <span><%= format_timestamp(run["finished_at"]) %></span>
                  </article>
                </div>

                <%= if replay_cancellable?(run) do %>
                  <div class="button-row" style="margin-top: 0.85rem;">
                    <button
                      type="button"
                      class="danger-button"
                      phx-click="cancel_replay"
                      phx-value-job_id={run["job_id"]}
                      disabled={!console_actions_enabled?(@snapshot)}
                    >
                      Cancel Replay
                    </button>
                  </div>
                <% end %>
              </article>
            <% end %>
          </div>

          <%= if replay_failures(@snapshot) != [] do %>
            <div class="run-list" style="margin-top: 1rem;">
              <%= for failure <- replay_failures(@snapshot) do %>
                <article class="run-card">
                  <strong><%= failure["projection_name"] %></strong>
                  <p class="helper-text"><%= failure["error_message"] %></p>
                  <p class="helper-text mono">log_seq <%= failure["log_seq"] || "n/a" %> / trace <%= failure["trace_id"] || "n/a" %></p>
                </article>
              <% end %>
            </div>
          <% end %>
        </section>

        <section id="stream" class="panel">
          <div class="panel-header">
            <div>
              <h2>Live Event Stream</h2>
              <p>Most recent tenant events with payload drill-down for live operational monitoring.</p>
            </div>
          </div>

          <%= if section_ready?(@snapshot.event_stream) do %>
            <div class="event-feed">
              <%= for event <- event_stream_items(@snapshot) do %>
                <article class="run-card">
                  <div class="trace-link-header">
                    <div>
                      <strong><%= event["event_type"] %></strong>
                      <p class="helper-text mono"><%= event["trace_id"] %> / <%= event["event_id"] %></p>
                    </div>

                    <span class={["status-chip", event_state_tone(event["event_type"])]}>
                      seq <%= event["log_seq"] %>
                    </span>
                  </div>

                  <div class="trace-summary-grid" style="margin-top: 0.85rem;">
                    <article class="detail-card">
                      <strong>Occurred</strong>
                      <span><%= format_timestamp(event["occurred_at"]) %></span>
                    </article>
                    <article class="detail-card">
                      <strong>Actor</strong>
                      <span class="mono"><%= actor_label(event["actor"]) %></span>
                    </article>
                    <article class="detail-card">
                      <strong>Summary</strong>
                      <span><%= event_excerpt(event) %></span>
                    </article>
                  </div>

                  <details style="margin-top: 0.85rem;">
                    <summary><strong>Payload</strong></summary>
                    <div class="payload-box">
                      <pre><%= pretty_json(event["payload"]) %></pre>
                    </div>
                  </details>
                </article>
              <% end %>
            </div>
          <% else %>
            <div class="empty-state">
              <h3>Event stream unavailable</h3>
              <p><%= @snapshot.event_stream.error %></p>
            </div>
          <% end %>
        </section>
      </section>
    """
  end

  attr :snapshot, :map, required: true

  defp status_surface(assigns) do
    ~H"""
    <section id="status" class="panel-grid">
      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Tenant Status</h2>
            <p>Operational summary for the currently selected tenant.</p>
          </div>
        </div>

        <%= if section_ready?(@snapshot.tenant_status) do %>
          <% tenant = tenant_status_data(@snapshot) %>
          <div class="metric-grid">
            <article class="detail-card">
              <span class="metric-label">Trace Count</span>
              <strong><%= tenant["trace_count"] %></strong>
            </article>
            <article class="detail-card">
              <span class="metric-label">Active Traces</span>
              <strong><%= tenant["active_trace_count"] %></strong>
            </article>
            <article class="detail-card">
              <span class="metric-label">Completed Traces</span>
              <strong><%= tenant["completed_trace_count"] %></strong>
            </article>
            <article class="detail-card">
              <span class="metric-label">Last Event</span>
              <strong><%= format_timestamp(tenant["last_event_at"]) %></strong>
            </article>
          </div>

          <div class="run-list" style="margin-top: 1rem;">
            <%= for workflow <- tenant_workflows(@snapshot) do %>
              <article class="run-card">
                <strong><%= workflow["workflow"] %></strong>
                <p class="helper-text"><%= workflow["trace_count"] %> traces</p>
              </article>
            <% end %>
          </div>
        <% else %>
          <div class="empty-state">
            <h3>Tenant status unavailable</h3>
            <p><%= @snapshot.tenant_status.error %></p>
          </div>
        <% end %>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Environment Status</h2>
            <p>Runtime and datastore facts that help operators spot degraded platform posture quickly.</p>
          </div>
        </div>

        <% env = environment_status_data(@snapshot) %>
        <div class="metric-grid">
          <article class="detail-card">
            <span class="metric-label">Deployment</span>
            <strong><%= env["deployment_env"] %></strong>
          </article>
          <article class="detail-card">
            <span class="metric-label">Database</span>
            <strong class="mono"><%= env["database"] %></strong>
          </article>
          <article class="detail-card">
            <span class="metric-label">Repo State</span>
            <strong><%= if env["repo_started?"], do: "online", else: "offline" %></strong>
          </article>
          <article class="detail-card">
            <span class="metric-label">Workers</span>
            <strong><%= env["active_workers"] %> / <%= env["partition_count"] %></strong>
          </article>
          <article class="detail-card">
            <span class="metric-label">Poll Interval</span>
            <strong><%= div(env["projection_poll_interval_ms"] || 0, 1_000) %>s</strong>
          </article>
          <article class="detail-card">
            <span class="metric-label">Batch Sizes</span>
            <strong><%= env["projection_batch_size"] %> / <%= env["projection_job_batch_size"] %></strong>
          </article>
        </div>
      </section>
    </section>
    """
  end

  defp console_styles(assigns) do
    ~H"""
    <style>
      .console-shell {
        background:
          radial-gradient(circle at top left, rgba(242, 143, 59, 0.18), transparent 24rem),
          radial-gradient(circle at top right, rgba(31, 108, 99, 0.16), transparent 22rem),
          linear-gradient(180deg, #f7f3ec 0%, #eef4f7 100%);
        color: #12313a;
        font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
        min-height: 100vh;
        padding: 2rem 1.25rem 3rem;
      }

      .console-frame {
        margin: 0 auto;
        max-width: 1340px;
      }

      .hero {
        animation: panel-in 420ms ease-out;
        background: linear-gradient(135deg, #11313e 0%, #1f6c63 58%, #f28f3b 100%);
        border-radius: 30px;
        box-shadow: 0 24px 80px rgba(17, 49, 62, 0.18);
        color: #fefbf5;
        display: grid;
        gap: 1.5rem;
        grid-template-columns: minmax(0, 1.7fr) minmax(280px, 1fr);
        overflow: hidden;
        padding: 2rem;
        position: relative;
      }

      .hero::after {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.16), transparent);
        content: "";
        inset: 0;
        pointer-events: none;
        position: absolute;
      }

      .eyebrow {
        font-size: 0.76rem;
        font-weight: 700;
        letter-spacing: 0.18em;
        margin: 0 0 0.75rem;
        opacity: 0.72;
        text-transform: uppercase;
      }

      .hero h1 {
        font-size: clamp(2.2rem, 4vw, 3.6rem);
        line-height: 0.96;
        margin: 0;
        max-width: 14ch;
      }

      .hero-copy p:last-child {
        font-size: 1.06rem;
        line-height: 1.7;
        margin: 1rem 0 0;
        max-width: 46rem;
        opacity: 0.92;
      }

      .hero-side {
        align-content: space-between;
        backdrop-filter: blur(16px);
        background: rgba(254, 251, 245, 0.12);
        border: 1px solid rgba(254, 251, 245, 0.22);
        border-radius: 24px;
        display: grid;
        gap: 1rem;
        padding: 1.25rem;
        position: relative;
        z-index: 1;
      }

      .hero-kicker,
      .subnav,
      .button-row,
      .chip-row {
        display: flex;
        flex-wrap: wrap;
        gap: 0.65rem;
      }

      .hero-chip,
      .subnav a {
        border-radius: 999px;
        font-size: 0.82rem;
        font-weight: 600;
        padding: 0.45rem 0.75rem;
      }

      .hero-chip {
        background: rgba(255, 255, 255, 0.15);
        border: 1px solid rgba(255, 255, 255, 0.18);
      }

      .hero-meta {
        display: grid;
        gap: 0.7rem;
      }

      .hero-meta strong,
      .trace-summary-grid strong,
      .event-facts strong,
      .field label,
      .metric-label {
        display: block;
        font-size: 0.78rem;
        letter-spacing: 0.06em;
        margin-bottom: 0.25rem;
        opacity: 0.7;
        text-transform: uppercase;
      }

      .hero-actions {
        align-items: center;
        display: flex;
        gap: 0.8rem;
        justify-content: space-between;
      }

      .refresh-button,
      .primary-button,
      .ghost-button,
      .danger-button {
        border: none;
        border-radius: 999px;
        cursor: pointer;
        font: inherit;
        font-weight: 700;
        padding: 0.75rem 1rem;
      }

      .refresh-button,
      .ghost-button {
        background: #fefbf5;
        color: #11313e;
      }

      .primary-button {
        background: #1f6c63;
        color: #fefbf5;
      }

      .danger-button {
        background: #b33c2d;
        color: #fff7f0;
      }

      .refresh-button:disabled,
      .primary-button:disabled,
      .ghost-button:disabled,
      .danger-button:disabled {
        cursor: not-allowed;
        opacity: 0.55;
      }

      .helper-text {
        font-size: 0.92rem;
        opacity: 0.72;
      }

      .banner,
      .alert-card {
        border-radius: 20px;
        margin-top: 1rem;
        padding: 0.95rem 1rem;
      }

      .banner {
        background: rgba(31, 108, 99, 0.1);
        border: 1px solid rgba(31, 108, 99, 0.18);
      }

      .alert-stack,
      .sidebar-stack,
      .run-list,
      .empty-state,
      .trace-events,
      .event-feed,
      .graph-list,
      .precedent-list {
        display: grid;
        gap: 0.85rem;
      }

      .alert-card h3 {
        margin: 0 0 0.35rem;
      }

      .alert-card p,
      .empty-state p {
        margin: 0;
      }

      .alert-info {
        background: rgba(17, 49, 62, 0.08);
        border: 1px solid rgba(17, 49, 62, 0.12);
      }

      .alert-warn {
        background: rgba(242, 143, 59, 0.13);
        border: 1px solid rgba(242, 143, 59, 0.22);
      }

      .alert-alert {
        background: rgba(179, 60, 45, 0.12);
        border: 1px solid rgba(179, 60, 45, 0.22);
      }

      .summary-grid,
      .console-grid,
      .panel-grid,
      .trace-summary-grid,
      .metric-grid {
        display: grid;
        gap: 1rem;
      }

      .summary-grid,
      .trace-summary-grid,
      .metric-grid {
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      }

      .summary-grid,
      .console-grid,
      .panel-grid {
        margin-top: 1rem;
      }

      .console-grid,
      .panel-grid {
        align-items: start;
        grid-template-columns: minmax(0, 1.2fr) minmax(280px, 0.8fr);
      }

      .panel,
      .metric-card,
      .detail-card,
      .trace-link,
      .event-card,
      .run-card {
        animation: panel-in 520ms ease-out;
        background: rgba(255, 252, 248, 0.92);
        border: 1px solid rgba(17, 49, 62, 0.08);
        border-radius: 24px;
        box-shadow: 0 16px 40px rgba(17, 49, 62, 0.08);
      }

      .metric-card,
      .detail-card,
      .run-card,
      .trace-link,
      .event-card {
        padding: 1rem;
      }

      .panel {
        padding: 1.25rem;
      }

      .metric-card h2,
      .panel h2 {
        font-size: 0.88rem;
        letter-spacing: 0.08em;
        margin: 0;
        opacity: 0.68;
        text-transform: uppercase;
      }

      .metric-card p {
        font-size: 1.8rem;
        font-weight: 700;
        margin: 0.65rem 0 0;
      }

      .metric-card span {
        display: block;
        font-size: 0.92rem;
        margin-top: 0.4rem;
        opacity: 0.7;
      }

      .panel-header,
      .trace-link-header,
      .event-header {
        align-items: flex-start;
        display: flex;
        gap: 0.75rem;
        justify-content: space-between;
      }

      .panel-header {
        margin-bottom: 1rem;
      }

      .panel-header p {
        margin: 0.35rem 0 0;
        max-width: 40rem;
        opacity: 0.74;
      }

      .status-chip {
        border-radius: 999px;
        display: inline-flex;
        font-size: 0.78rem;
        font-weight: 700;
        gap: 0.3rem;
        letter-spacing: 0.06em;
        padding: 0.35rem 0.65rem;
        text-transform: uppercase;
        white-space: nowrap;
      }

      .status-good {
        background: rgba(31, 108, 99, 0.12);
        color: #146156;
      }

      .status-warn {
        background: rgba(242, 143, 59, 0.15);
        color: #a65411;
      }

      .status-alert {
        background: rgba(179, 60, 45, 0.14);
        color: #a13124;
      }

      .status-neutral {
        background: rgba(17, 49, 62, 0.08);
        color: #395862;
      }

      .trace-link {
        color: inherit;
        display: grid;
        gap: 0.6rem;
        text-decoration: none;
      }

      .trace-link.is-selected {
        border-color: rgba(242, 143, 59, 0.52);
        box-shadow: 0 14px 28px rgba(242, 143, 59, 0.12);
      }

      .mono {
        font-family: "IBM Plex Mono", Consolas, monospace;
        font-size: 0.9rem;
      }

      .event-card {
        border-left: 4px solid #f28f3b;
      }

      .event-seq {
        align-items: center;
        background: rgba(242, 143, 59, 0.14);
        border-radius: 999px;
        color: #a65411;
        display: inline-flex;
        font-size: 0.86rem;
        font-weight: 700;
        justify-content: center;
        min-width: 2.2rem;
        padding: 0.35rem 0.65rem;
      }

      .payload-box {
        background: #11313e;
        border-radius: 16px;
        color: #f6f1e8;
        margin-top: 0.8rem;
        overflow-x: auto;
        padding: 0.9rem;
      }

      .payload-box pre {
        margin: 0;
        white-space: pre-wrap;
        word-break: break-word;
      }

      .empty-state {
        align-items: start;
        background: rgba(255, 255, 255, 0.62);
        border: 1px dashed rgba(17, 49, 62, 0.18);
        border-radius: 18px;
        padding: 1rem;
      }

      .health-table {
        border-collapse: collapse;
        width: 100%;
      }

      .health-table th,
      .health-table td {
        border-top: 1px solid rgba(17, 49, 62, 0.08);
        padding: 0.85rem 0.6rem;
        text-align: left;
        vertical-align: top;
      }

      .health-table th {
        font-size: 0.82rem;
        letter-spacing: 0.08em;
        opacity: 0.6;
        text-transform: uppercase;
      }

      .field {
        display: grid;
        gap: 0.45rem;
      }

      .field input,
      .field textarea,
      .field select {
        background: rgba(255, 255, 255, 0.92);
        border: 1px solid rgba(17, 49, 62, 0.14);
        border-radius: 16px;
        color: #12313a;
        font: inherit;
        padding: 0.75rem 0.9rem;
      }

      .field textarea {
        min-height: 5.5rem;
        resize: vertical;
      }

      @keyframes panel-in {
        from {
          opacity: 0;
          transform: translateY(10px);
        }

        to {
          opacity: 1;
          transform: translateY(0);
        }
      }

      @media (max-width: 980px) {
        .hero,
        .console-grid,
        .panel-grid {
          grid-template-columns: 1fr;
        }
      }
    </style>
    """
  end

  defp queue_snapshot_refresh(socket) do
    send(
      self(),
      {:load_snapshot, socket.assigns.tenant_id, socket.assigns.trace_id,
       socket.assigns.workflow_id}
    )

    assign(socket, :loading, true)
  end

  defp snapshot_for(tenant_id, trace_id, workflow_id) do
    DecisionGraph.Api.service(:console).snapshot(
      tenant_id: tenant_id,
      trace_id: trace_id,
      workflow_id: workflow_id
    )
  end

  defp default_replay_form do
    %{
      "confirm_text" => "",
      "mode" => "catch_up",
      "projection" => "trace_summary",
      "reason" => ""
    }
  end

  defp default_workflow_form do
    %{
      "action" => "approve",
      "assigned_account_id" => "",
      "assigned_role" => "",
      "confirm_text" => "",
      "note" => "",
      "reason" => ""
    }
  end

  defp default_review_form do
    %{
      "reason" => "",
      "template_id" => "incident_triage"
    }
  end

  defp replay_form_from_params(params, fallback) do
    %{
      "confirm_text" =>
        string_value(params, "confirm_text", replay_form_value(fallback, "confirm_text")),
      "mode" =>
        normalize_replay_mode(string_value(params, "mode", replay_form_value(fallback, "mode"))),
      "projection" =>
        normalize_replay_projection(
          string_value(params, "projection", replay_form_value(fallback, "projection"))
        ),
      "reason" => string_value(params, "reason", replay_form_value(fallback, "reason"))
    }
  end

  defp replay_request_attrs(form, trace_id) do
    %{
      "metadata" =>
        %{}
        |> maybe_put("selected_trace_id", trace_id)
        |> Map.put("requested_from", "operator_console"),
      "mode" => replay_form_value(form, "mode"),
      "projection" => replay_form_value(form, "projection"),
      "reason" => replay_form_value(form, "reason")
    }
  end

  defp reset_replay_form(form) do
    form
    |> Map.put("confirm_text", "")
    |> Map.put("reason", "")
  end

  defp review_form_from_params(params, fallback) do
    %{
      "reason" => string_value(params, "reason", review_form_value(fallback, "reason")),
      "template_id" =>
        string_value(params, "template_id", review_form_value(fallback, "template_id"))
    }
  end

  defp review_request_attrs(form) do
    %{
      "reason" => review_form_value(form, "reason"),
      "template_id" => review_form_value(form, "template_id")
    }
  end

  defp reset_review_form(form) do
    form
    |> Map.put("reason", "")
  end

  defp workflow_form_from_params(params, fallback) do
    %{
      "action" => string_value(params, "action", workflow_form_value(fallback, "action")),
      "assigned_account_id" =>
        string_value(
          params,
          "assigned_account_id",
          workflow_form_value(fallback, "assigned_account_id")
        ),
      "assigned_role" =>
        string_value(params, "assigned_role", workflow_form_value(fallback, "assigned_role")),
      "confirm_text" =>
        string_value(params, "confirm_text", workflow_form_value(fallback, "confirm_text")),
      "note" => string_value(params, "note", workflow_form_value(fallback, "note")),
      "reason" => string_value(params, "reason", workflow_form_value(fallback, "reason"))
    }
  end

  defp workflow_request_attrs(form) do
    %{}
    |> Map.put("action", workflow_form_value(form, "action"))
    |> maybe_put(
      "assigned_account_id",
      blank_to_nil(workflow_form_value(form, "assigned_account_id"))
    )
    |> maybe_put("assigned_role", blank_to_nil(workflow_form_value(form, "assigned_role")))
    |> maybe_put("confirm_text", blank_to_nil(workflow_form_value(form, "confirm_text")))
    |> maybe_put("note", blank_to_nil(workflow_form_value(form, "note")))
    |> maybe_put("reason", blank_to_nil(workflow_form_value(form, "reason")))
  end

  defp reset_workflow_form(form) do
    form
    |> Map.put("assigned_account_id", "")
    |> Map.put("assigned_role", "")
    |> Map.put("confirm_text", "")
    |> Map.put("note", "")
    |> Map.put("reason", "")
  end

  defp validate_replay_form(form, snapshot) do
    cond do
      not console_actions_enabled?(snapshot) ->
        {:error, get_in(snapshot, [:console_controls, :error]) || "Replay actions are disabled."}

      replay_form_value(form, "mode") == "rebuild" and not console_can_rebuild?(snapshot) ->
        {:error, "The configured console actor cannot request rebuild operations."}

      String.trim(replay_form_value(form, "reason")) == "" ->
        {:error, "Replay reason is required."}

      String.trim(replay_form_value(form, "confirm_text")) != replay_confirmation_phrase(form) ->
        {:error, "Type the exact confirmation phrase before queueing the replay."}

      true ->
        :ok
    end
  end

  defp validate_workflow_form(form, snapshot) do
    action = workflow_form_value(form, "action")

    cond do
      not workflow_actions_enabled?(snapshot) ->
        {:error, "The configured console actor cannot perform workflow actions."}

      action in ["approve", "reject", "request_change", "override"] and
          blank?(workflow_form_value(form, "reason")) ->
        {:error, "A reason is required for this workflow action."}

      action == "escalate" and blank?(workflow_form_value(form, "reason")) ->
        {:error, "Escalation requires a reason."}

      action == "reassign" and
        blank?(workflow_form_value(form, "assigned_account_id")) and
          blank?(workflow_form_value(form, "assigned_role")) ->
        {:error, "Reassign requires an account or role target."}

      action == "comment" and blank?(workflow_form_value(form, "note")) ->
        {:error, "Comments need a note."}

      action == "override" and
          workflow_form_value(form, "confirm_text") !=
            workflow_override_confirmation_phrase(selected_workflow_item(snapshot)) ->
        {:error, "Type the exact override confirmation phrase before submitting."}

      true ->
        :ok
    end
  end

  defp validate_review_form(form, snapshot) do
    cond do
      not console_can_workflow_assign?(snapshot) ->
        {:error, "The configured console actor cannot start workflow reviews."}

      blank?(review_form_value(form, "reason")) ->
        {:error, "A reason is required to start a trace review."}

      true ->
        :ok
    end
  end

  defp selected_workflow_id_result(snapshot) do
    case selected_workflow_id(snapshot) do
      nil -> {:error, "Select a workflow item first."}
      workflow_id -> {:ok, workflow_id}
    end
  end

  defp selected_trace_id_result(snapshot) do
    case selected_trace_id(snapshot) do
      nil -> {:error, "Select a trace first."}
      trace_id -> {:ok, trace_id}
    end
  end

  defp replay_confirmation_phrase(form) do
    "#{String.upcase(replay_form_value(form, "mode"))} #{String.upcase(replay_form_value(form, "projection"))}"
  end

  defp replay_projection_options, do: @replay_projections
  defp replay_form_value(form, key), do: Map.get(form, key, "")
  defp review_form_value(form, key), do: Map.get(form, key, "")
  defp workflow_form_value(form, key), do: Map.get(form, key, "")
  defp normalize_replay_mode(mode) when mode in ["catch_up", "rebuild"], do: mode
  defp normalize_replay_mode(_mode), do: "catch_up"

  defp normalize_replay_projection(projection) when projection in @replay_projections,
    do: projection

  defp normalize_replay_projection(_projection), do: "trace_summary"

  defp console_alerts(snapshot), do: Map.get(snapshot, :alerts, [])
  defp section_ready?(%{status: "ready"}), do: true
  defp section_ready?(_section), do: false

  defp projection_rows(snapshot),
    do: get_in(snapshot, [:projection_health, :data, "projections"]) || []

  defp recent_traces(snapshot), do: get_in(snapshot, [:recent_traces, :items]) || []

  defp selected_trace_events(snapshot),
    do: get_in(snapshot, [:selected_trace, :data, "events"]) || []

  defp selected_trace_summary(snapshot),
    do: get_in(snapshot, [:selected_trace, :data, "summary"]) || %{}

  defp selected_trace_id(snapshot), do: get_in(snapshot, [:selected_trace, :trace_id])

  defp trace_handoff(snapshot),
    do: get_in(snapshot, [:selected_trace, :data, "investigator_handoff"])

  defp graph_data(snapshot), do: get_in(snapshot, [:context_graph, :data]) || %{}
  defp graph_nodes(snapshot), do: get_in(snapshot, [:context_graph, :data, "nodes"]) || []
  defp graph_edges(snapshot), do: get_in(snapshot, [:context_graph, :data, "edges"]) || []
  defp precedent_focus(snapshot), do: get_in(snapshot, [:precedents, :data, "focus"]) || %{}
  defp precedent_items(snapshot), do: get_in(snapshot, [:precedents, :data, "items"]) || []
  defp policy_review_data(snapshot), do: get_in(snapshot, [:policy_review, :data]) || %{}
  defp policy_timeline(snapshot), do: get_in(snapshot, [:policy_review, :data, "timeline"]) || []
  defp replay_runs(snapshot), do: get_in(snapshot, [:replay_console, :data, "runs"]) || []

  defp replay_failures(snapshot),
    do: get_in(snapshot, [:replay_console, :data, "latest_failures"]) || []

  defp replay_digest_rows(snapshot),
    do: get_in(snapshot, [:replay_console, :data, "projection_digests"]) || []

  defp replay_full_digest(snapshot), do: get_in(snapshot, [:replay_console, :data, "full_digest"])
  defp event_stream_items(snapshot), do: get_in(snapshot, [:event_stream, :items]) || []
  defp tenant_status_data(snapshot), do: get_in(snapshot, [:tenant_status, :data]) || %{}

  defp workflow_inbox_items(snapshot),
    do: get_in(snapshot, [:workflow_inbox, :data, "items"]) || []

  defp workflow_actions(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "actions"]) || []

  defp workflow_notifications(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "notifications"]) || []

  defp workflow_review_context(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "review_context"])

  defp selected_workflow_item(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "workflow"]) || %{}

  defp selected_workflow_id(snapshot), do: get_in(snapshot, [:selected_workflow, :workflow_id])

  defp review_studio_templates(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "templates"]) || []

  defp review_studio_template(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "template"]) || %{}

  defp review_studio_simulation(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "simulation"]) || %{}

  defp review_studio_existing_workflows(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "existing_workflows"]) || []

  defp review_studio_precedents(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "precedent_preview"]) || []

  defp review_studio_replay(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "replay_suggestion"]) || %{}

  defp review_studio_draft(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "draft"]) || %{}

  defp tenant_workflows(snapshot),
    do: get_in(snapshot, [:tenant_status, :data, "workflows"]) || []

  defp environment_status_data(snapshot),
    do: get_in(snapshot, [:environment_status, :data]) || %{}

  defp tenant_metric(snapshot, key), do: get_in(snapshot, [:tenant_status, :data, key]) || 0
  defp trace_selected?(snapshot, trace_id), do: selected_trace_id(snapshot) == trace_id

  defp workflow_selected?(snapshot, workflow_id),
    do: selected_workflow_id(snapshot) == workflow_id

  defp workflow_summary_metric(snapshot, key),
    do: get_in(snapshot, [:workflow_inbox, :summary, key]) || 0

  defp console_actions_enabled?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "actions_enabled"]) in [true, "true"]
  end

  defp console_can_rebuild?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_rebuild"]) in [true, "true"]
  end

  defp console_actor_label(snapshot) do
    get_in(snapshot, [:console_controls, :data, "account_id"]) || "disabled"
  end

  defp workflow_actions_enabled?(snapshot) do
    console_can_workflow_review?(snapshot) or console_can_workflow_assign?(snapshot) or
      console_can_workflow_override?(snapshot) or console_can_workflow_escalate?(snapshot)
  end

  defp workflow_action_options(snapshot) do
    []
    |> maybe_push(console_can_workflow_review?(snapshot), "approve")
    |> maybe_push(console_can_workflow_review?(snapshot), "reject")
    |> maybe_push(console_can_workflow_review?(snapshot), "request_change")
    |> maybe_push(console_can_workflow_review?(snapshot), "comment")
    |> maybe_push(console_can_workflow_escalate?(snapshot), "escalate")
    |> maybe_push(console_can_workflow_assign?(snapshot), "reassign")
    |> maybe_push(console_can_workflow_override?(snapshot), "override")
  end

  defp console_can_workflow_review?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_review"]) in [true, "true"]
  end

  defp console_can_workflow_assign?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_assign"]) in [true, "true"]
  end

  defp console_can_workflow_escalate?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_escalate"]) in [true, "true"]
  end

  defp console_can_workflow_override?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_override"]) in [true, "true"]
  end

  defp projection_summary_label(%{projection_health: %{summary: %{open_failures: failures}}})
       when failures > 0,
       do: "operator attention"

  defp projection_summary_label(%{projection_health: %{summary: %{stale_count: stale_count}}})
       when stale_count > 0,
       do: "catching up"

  defp projection_summary_label(%{projection_health: %{status: "ready"}}), do: "healthy"
  defp projection_summary_label(_snapshot), do: "unavailable"

  defp projection_summary_tone(%{projection_health: %{summary: %{open_failures: failures}}})
       when failures > 0,
       do: "status-alert"

  defp projection_summary_tone(%{projection_health: %{summary: %{stale_count: stale_count}}})
       when stale_count > 0,
       do: "status-warn"

  defp projection_summary_tone(%{projection_health: %{status: "ready"}}), do: "status-good"
  defp projection_summary_tone(_snapshot), do: "status-neutral"

  defp projection_status_label(projection) do
    cond do
      projection["open_failures"] > 0 -> "failing"
      projection["is_stale"] -> "stale"
      projection["pending_events"] > 0 -> "catching up"
      true -> "ready"
    end
  end

  defp projection_status_tone(projection) do
    cond do
      projection["open_failures"] > 0 -> "status-alert"
      projection["is_stale"] -> "status-warn"
      projection["pending_events"] > 0 -> "status-warn"
      true -> "status-good"
    end
  end

  defp trace_state_tone(state) when state in ["success", "allow", "approved", "completed"],
    do: "status-good"

  defp trace_state_tone(state) when state in ["running", "pending", "requested", "reviewed"],
    do: "status-warn"

  defp trace_state_tone(state) when state in ["failed", "rejected", "deny", "denied"],
    do: "status-alert"

  defp trace_state_tone(_state), do: "status-neutral"
  defp event_state_tone("TraceFinished"), do: "status-good"
  defp event_state_tone("ApprovalRecorded"), do: "status-good"
  defp event_state_tone("ActionCommitted"), do: "status-good"
  defp event_state_tone("PolicyEvaluated"), do: "status-warn"
  defp event_state_tone("ExceptionRequested"), do: "status-alert"
  defp event_state_tone(_event_type), do: "status-neutral"
  defp replay_status_tone(status) when status in ["failed", "cancelled"], do: "status-alert"
  defp replay_status_tone("running"), do: "status-warn"
  defp replay_status_tone("queued"), do: "status-neutral"
  defp replay_status_tone(_status), do: "status-good"
  defp alert_tone(%{"kind" => "alert"}), do: "alert-alert"
  defp alert_tone(%{"kind" => "warn"}), do: "alert-warn"
  defp alert_tone(_alert), do: "alert-info"

  defp workflow_status_tone(status, overdue?)
       when overdue? and status in ["requested", "in_review", "changes_requested"],
       do: "status-alert"

  defp workflow_status_tone(status, _overdue?) when status in ["approved"], do: "status-good"
  defp workflow_status_tone(status, _overdue?) when status in ["rejected"], do: "status-alert"
  defp workflow_status_tone(status, _overdue?) when status in ["overridden"], do: "status-warn"
  defp workflow_status_tone(status, _overdue?) when status in ["escalated"], do: "status-alert"

  defp workflow_status_tone(status, _overdue?) when status in ["requested", "changes_requested"],
    do: "status-warn"

  defp workflow_status_tone(_status, _overdue?), do: "status-neutral"

  defp workflow_assignee_label(workflow) do
    workflow["assigned_account_id"] || workflow["assigned_role"] || "unassigned"
  end

  defp workflow_subject_label(workflow) do
    subject = workflow["subject"] || %{}

    [subject["subject_type"], subject["subject_id"]]
    |> Enum.reject(&blank?/1)
    |> Enum.join(":")
    |> case do
      "" -> "unknown"
      label -> label
    end
  end

  defp workflow_due_label(nil, _overdue), do: "not set"
  defp workflow_due_label(timestamp, true), do: "overdue since " <> format_timestamp(timestamp)
  defp workflow_due_label(timestamp, false), do: format_timestamp(timestamp)

  defp workflow_override_confirmation_phrase(workflow) do
    "OVERRIDE " <> String.upcase(Map.get(workflow || %{}, "workflow_id", ""))
  end

  defp workflow_action_actor_label(action) do
    actor = action["actor"] || %{}
    actor["account_id"] || actor["actor_id"] || "unknown"
  end

  defp precedent_outcome_delta(snapshot, precedent) do
    current_outcome = get_in(snapshot, [:selected_trace, :data, "summary", "outcome"])
    precedent_outcome = precedent["outcome"]

    cond do
      blank?(current_outcome) or blank?(precedent_outcome) -> "insufficient signal"
      current_outcome == precedent_outcome -> "same outcome"
      true -> "#{precedent_outcome} vs #{current_outcome}"
    end
  end

  defp precedent_policy_label(precedent) do
    case [precedent["policy_id"], precedent["policy_version"]] |> Enum.reject(&blank?/1) do
      [] -> "policy lineage unavailable"
      parts -> Enum.join(parts, "@")
    end
  end

  defp replay_cancellable?(run), do: run["status"] in ["queued", "running"]

  defp digest_alignment_label(snapshot, digest) do
    case latest_completed_run_for_projection(snapshot, digest["projection_name"]) do
      nil ->
        "no completed replay"

      run ->
        cond do
          run["last_log_seq"] == digest["last_log_seq"] ->
            "aligned"

          (run["last_log_seq"] || 0) < (digest["last_log_seq"] || 0) ->
            "newer than last replay"

          true ->
            "needs review"
        end
    end
  end

  defp digest_alignment_tone(snapshot, digest) do
    case digest_alignment_label(snapshot, digest) do
      "aligned" -> "status-good"
      "no completed replay" -> "status-neutral"
      "newer than last replay" -> "status-warn"
      _other -> "status-alert"
    end
  end

  defp latest_completed_run_for_projection(snapshot, projection_name) do
    replay_runs(snapshot)
    |> Enum.filter(&(&1["projection_name"] == projection_name and &1["status"] == "completed"))
    |> List.first()
  end

  defp event_excerpt(event) do
    payload = event["payload"] || %{}

    value_from(payload, "decision") || value_from(payload, "action_id") ||
      value_from(payload, "exception_id") || "No short summary recorded."
  end

  defp policy_label(policy) when is_map(policy) do
    case [policy["policy_id"], policy["policy_version"]] |> Enum.reject(&blank?/1) do
      [] -> "policy unavailable"
      parts -> Enum.join(parts, "@")
    end
  end

  defp policy_label(_policy), do: "policy unavailable"
  defp short_digest(nil), do: "pending"

  defp short_digest(digest) when is_binary(digest) do
    if String.length(digest) > 20 do
      digest |> String.slice(0, 20) |> Kernel.<>("...")
    else
      digest
    end
  end

  defp format_timestamp(nil), do: "pending"

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    timestamp
    |> String.replace("T", " ")
    |> String.replace("Z", " UTC")
  end

  defp pretty_json(value), do: Jason.encode_to_iodata!(value || %{}, pretty: true)

  defp actor_label(%{"actor_id" => actor_id, "actor_type" => actor_type}),
    do: "#{actor_type}:#{actor_id}"

  defp actor_label(%{actor_id: actor_id, actor_type: actor_type}), do: "#{actor_type}:#{actor_id}"
  defp actor_label(_actor), do: "unknown"

  defp entity_label(summary) do
    [
      summary["primary_entity_system"],
      summary["primary_entity_type"],
      summary["primary_entity_id"]
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(":")
    |> case do
      "" -> "unknown"
      label -> label
    end
  end

  defp string_value(map, key, default) do
    map
    |> value_from(key, default)
    |> to_string()
    |> String.trim()
  end

  defp value_from(map, key, default \\ nil)

  defp value_from(map, key, default) when is_map(map) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp value_from(_map, _key, default), do: default
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
  defp maybe_push(list, true, value), do: list ++ [value]
  defp maybe_push(list, false, _value), do: list
  defp blank_to_nil(value) when is_binary(value) and value == "", do: nil
  defp blank_to_nil(value) when is_binary(value), do: value
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: value
  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp normalize_param(nil, fallback), do: fallback

  defp normalize_param(value, _fallback) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "default"
      normalized -> normalized
    end
  end

  defp normalize_optional_param(nil), do: nil

  defp normalize_optional_param(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end
end
