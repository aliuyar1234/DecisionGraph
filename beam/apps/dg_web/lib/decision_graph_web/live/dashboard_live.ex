defmodule DecisionGraphWeb.DashboardLive do
  use DecisionGraphWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :snapshot, DecisionGraph.Api.bootstrap_snapshot())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main style="font-family: 'Segoe UI', sans-serif; margin: 0 auto; max-width: 960px; padding: 3rem 1.5rem;">
      <section style="background: linear-gradient(135deg, #0f172a, #1e293b); border-radius: 24px; color: #f8fafc; padding: 2rem;">
        <p style="letter-spacing: 0.16em; margin: 0 0 0.5rem 0; opacity: 0.75; text-transform: uppercase;">
          DecisionGraph Phase 2
        </p>
        <h1 style="font-size: 2.5rem; line-height: 1.1; margin: 0;">
          BEAM runtime shell is online.
        </h1>
        <p style="font-size: 1.05rem; line-height: 1.6; margin: 1rem 0 0 0; max-width: 42rem;">
          The Python semantic oracle stays in place while the Elixir platform now owns application boundaries,
          supervision, environment config, observability context, and the first Phoenix delivery surface.
        </p>
      </section>

      <section style="display: grid; gap: 1rem; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); margin-top: 1.5rem;">
        <article style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 18px; padding: 1.25rem;">
          <h2 style="font-size: 1rem; margin: 0 0 0.5rem 0;">Deployment</h2>
          <p style="font-size: 1.5rem; font-weight: 700; margin: 0;"><%= @snapshot.deployment_env %></p>
        </article>

        <article style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 18px; padding: 1.25rem;">
          <h2 style="font-size: 1rem; margin: 0 0 0.5rem 0;">Projector Partitions</h2>
          <p style="font-size: 1.5rem; font-weight: 700; margin: 0;"><%= @snapshot.projector.partition_count %></p>
        </article>

        <article style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 18px; padding: 1.25rem;">
          <h2 style="font-size: 1rem; margin: 0 0 0.5rem 0;">Repo Started</h2>
          <p style="font-size: 1.5rem; font-weight: 700; margin: 0;"><%= @snapshot.store.repo_started? %></p>
        </article>
      </section>

      <section style="margin-top: 1.5rem;">
        <h2 style="font-size: 1.2rem;">Runtime Snapshot</h2>
        <pre style="background: #0f172a; border-radius: 18px; color: #cbd5e1; overflow-x: auto; padding: 1rem;"><%= Jason.encode_to_iodata!(@snapshot, pretty: true) %></pre>
      </section>
    </main>
    """
  end
end
