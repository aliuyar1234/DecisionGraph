# Operator Console Visual Direction

## Visual Intent

The operator console should feel like a calm control plane, not a default admin scaffold.

The implemented direction is:

- warm parchment and cool slate background gradients
- deep teal and amber as the primary operational accents
- IBM Plex Sans and IBM Plex Mono for readable but technical typography
- rounded, high-contrast cards that keep dense operational data scannable

## Key UI Rules

- critical state should appear as banners and chips before it appears inside tables
- traces, runs, precedents, and events should all render as readable cards before falling back to raw JSON
- payload inspection should be available everywhere it matters, but hidden behind `details` so the console stays calm
- the selected trace should stay visually obvious while moving between graph, precedent, and replay panels

## Status Language

- `status-good`: healthy, complete, approved, aligned
- `status-warn`: catching up, stale, running, newer than last replay
- `status-alert`: failing, exception requested, rejected, recovery needed
- `status-neutral`: contextual metadata or incomplete signal

## Degraded-State Rules

- stale projections surface in both summary cards and alert banners
- unavailable sections show explicit empty-state copy instead of rendering partial garbage
- replay actions show the operator actor and stay disabled when no console actor is configured
- loading uses a visible banner so refresh cycles feel intentional instead of silent
