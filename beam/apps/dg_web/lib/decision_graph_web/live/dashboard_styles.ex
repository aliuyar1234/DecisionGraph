defmodule DecisionGraphWeb.DashboardStyles do
  @moduledoc false

  use Phoenix.Component

  def console_styles(assigns) do
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
end
