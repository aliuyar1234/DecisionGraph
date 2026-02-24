"""Performance benchmarks + guardrails for DecisionGraph."""

from __future__ import annotations

import argparse
import json
import math
import statistics
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import NodeRef, get_context_subgraph, get_trace_events
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope

REPO_ROOT = Path(__file__).resolve().parents[1]


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    sorted_values = sorted(values)
    rank = (len(sorted_values) - 1) * percentile
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return sorted_values[lower]
    weight = rank - lower
    return sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight


def _append_events(
    store: SQLiteEventStore,
    trace_id: str,
    event_count: int,
    *,
    id_prefix: str,
) -> None:
    if event_count <= 0:
        return

    start = create_test_envelope(
        trace_id=trace_id,
        trace_seq=0,
        event_type=EVENT_TYPE_TRACE_STARTED,
        payload={
            "workflow": "perf",
            "title": f"perf-{id_prefix}",
            "primary_entity": {"entity_type": "account", "entity_id": f"{id_prefix}-0"},
        },
        idempotency_key=f"start:{id_prefix}",
    )
    store.append_event(start)

    for seq in range(1, event_count):
        event = create_test_envelope(
            trace_id=trace_id,
            trace_seq=seq,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={
                "entity": {"entity_type": "account", "entity_id": f"{id_prefix}-{seq % 500}"},
                "role": "related",
                "facts": [],
            },
            idempotency_key=f"{id_prefix}:{seq}",
        )
        store.append_event(event)


def _project_all_events_in_batches(
    store: SQLiteEventStore, projector: SQLiteProjector, batch_size: int
) -> None:
    since_log_seq = 0
    while True:
        batch = store.list_events(since_log_seq=since_log_seq, limit=batch_size)
        if not batch:
            return
        projector.project_events(batch)
        since_log_seq = batch[-1].log_seq


def benchmark_core_operations(*, replay_batch_size: int) -> dict[str, float]:
    append_latencies_ms: list[float] = []
    with SQLiteEventStore(":memory:") as append_store:
        trace_id = generate_trace_id()
        start_event = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "perf", "title": "append benchmark"},
            idempotency_key="append:start",
        )
        append_store.append_event(start_event)

        for seq in range(1, 401):
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=seq,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "account", "entity_id": f"acct-{seq}"},
                    "role": "related",
                    "facts": [],
                },
                idempotency_key=f"append:{seq}",
            )
            started = time.perf_counter()
            append_store.append_event(env)
            append_latencies_ms.append((time.perf_counter() - started) * 1000.0)

    with SQLiteEventStore(":memory:") as query_store:
        trace_id = generate_trace_id()
        _append_events(query_store, trace_id, 320, id_prefix="query")
        query_latencies_ms: list[float] = []
        for _ in range(150):
            started = time.perf_counter()
            get_trace_events(query_store, trace_id=trace_id, limit=100)
            query_latencies_ms.append((time.perf_counter() - started) * 1000.0)

    with SQLiteEventStore(":memory:") as graph_store:
        trace_id = generate_trace_id()
        _append_events(graph_store, trace_id, 600, id_prefix="graph")
        projector = SQLiteProjector(graph_store.connection)
        projector.rebuild()
        projector.project_events(graph_store.list_events())

        graph_latencies_ms: list[float] = []
        center = NodeRef(node_type="trace", node_id=trace_id)
        for _ in range(120):
            started = time.perf_counter()
            get_context_subgraph(graph_store, projector, center, max_depth=2)
            graph_latencies_ms.append((time.perf_counter() - started) * 1000.0)

    with tempfile.TemporaryDirectory(prefix="dg-perf-core-") as temp_dir:
        db_path = Path(temp_dir) / "replay-10000.db"
        with SQLiteEventStore(str(db_path)) as replay_store:
            trace_id = generate_trace_id()
            _append_events(replay_store, trace_id, 10_000, id_prefix="replay")
            projector = SQLiteProjector(replay_store.connection)
            projector.rebuild()

            started = time.perf_counter()
            _project_all_events_in_batches(
                replay_store,
                projector,
                batch_size=replay_batch_size,
            )
            replay_10000_ms = (time.perf_counter() - started) * 1000.0

    return {
        "append_mean_ms": statistics.fmean(append_latencies_ms),
        "append_p95_ms": _percentile(append_latencies_ms, 0.95),
        "trace_query_100_ms": statistics.fmean(query_latencies_ms),
        "subgraph_depth2_ms": statistics.fmean(graph_latencies_ms),
        "replay_10000_ms": replay_10000_ms,
    }


def benchmark_scaling(
    *,
    event_counts: list[int],
    replay_batch_size: int,
    workdir: Path,
) -> dict[str, dict[str, float]]:
    scaling: dict[str, dict[str, float]] = {}
    workdir.mkdir(parents=True, exist_ok=True)
    run_dir = workdir / f"run-{uuid.uuid4().hex}"
    run_dir.mkdir(parents=True, exist_ok=True)

    for count in event_counts:
        db_path = run_dir / f"scaling-{count}.db"

        with SQLiteEventStore(str(db_path)) as store:
            trace_id = generate_trace_id()
            _append_events(store, trace_id, count, id_prefix=f"scale-{count}")
            projector = SQLiteProjector(store.connection)
            projector.rebuild()

            started = time.perf_counter()
            _project_all_events_in_batches(
                store,
                projector,
                batch_size=replay_batch_size,
            )
            replay_ms = (time.perf_counter() - started) * 1000.0

        scaling[str(count)] = {
            "event_count": float(count),
            "replay_ms": replay_ms,
            "db_size_bytes": float(db_path.stat().st_size),
        }

    return scaling


def _check_metric_against_budget(
    metric_name: str,
    actual: float,
    budget: float,
    baseline: float | None,
    variance_threshold: float,
) -> list[str]:
    failures: list[str] = []
    if actual > budget:
        failures.append(f"{metric_name}: {actual:.2f} > budget {budget:.2f}")
    if baseline is not None:
        allowed = baseline * (1.0 + variance_threshold)
        if actual > allowed:
            failures.append(
                f"{metric_name}: {actual:.2f} > variance cap {allowed:.2f} "
                f"(baseline {baseline:.2f}, threshold {variance_threshold:.2f})"
            )
    return failures


def enforce_guardrails(
    core_metrics: dict[str, float],
    scaling_metrics: dict[str, dict[str, float]],
    *,
    baseline_config: dict[str, Any],
) -> list[str]:
    failures: list[str] = []

    variance_threshold = float(baseline_config.get("variance_threshold", 0.5))
    core_budgets: dict[str, float] = baseline_config.get("core_budgets_ms", {})
    core_baseline: dict[str, float] = baseline_config.get("core_baseline_ms", {})

    for metric_name, budget in core_budgets.items():
        actual = core_metrics[metric_name]
        baseline = core_baseline.get(metric_name)
        failures.extend(
            _check_metric_against_budget(
                metric_name,
                actual,
                budget,
                baseline,
                variance_threshold,
            )
        )

    scaling_budgets: dict[str, float] = baseline_config.get("scaling_budgets_ms", {})
    scaling_baseline: dict[str, float] = baseline_config.get("scaling_baseline_ms", {})
    previous_size: float | None = None
    previous_replay: float | None = None
    for size_key in sorted(scaling_metrics, key=lambda item: int(item)):
        replay_ms = scaling_metrics[size_key]["replay_ms"]
        size_bytes = scaling_metrics[size_key]["db_size_bytes"]
        budget = scaling_budgets.get(size_key)
        baseline = scaling_baseline.get(size_key)
        if budget is not None:
            failures.extend(
                _check_metric_against_budget(
                    f"replay_{size_key}_ms",
                    replay_ms,
                    budget,
                    baseline,
                    variance_threshold,
                )
            )

        if previous_size is not None and size_bytes < previous_size:
            failures.append(
                f"db_size_bytes not monotonic: {size_key} has {size_bytes} < {previous_size}"
            )
        if previous_replay is not None and replay_ms < previous_replay * 0.8:
            failures.append(
                f"replay_ms unexpectedly dropped: {size_key} has {replay_ms:.2f} < "
                f"80% of previous {previous_replay:.2f}"
            )

        previous_size = size_bytes
        previous_replay = replay_ms

    return failures


def main() -> None:
    parser = argparse.ArgumentParser(description="Run DecisionGraph performance guardrails")
    parser.add_argument(
        "--mode",
        choices=["quick", "full"],
        default="quick",
        help="quick: 1k/10k scaling, full: 1k/10k/100k scaling",
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        default=REPO_ROOT / "specs" / "performance" / "baseline.json",
        help="Baseline/budget configuration JSON",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional JSON output path for benchmark results",
    )
    parser.add_argument(
        "--workdir",
        type=Path,
        default=REPO_ROOT / ".tmp" / "perf",
        help="Directory for generated performance artifacts",
    )
    parser.add_argument(
        "--replay-batch-size",
        type=int,
        default=5000,
        help="Batch size for replay operations",
    )
    parser.add_argument(
        "--enforce",
        action="store_true",
        help="Fail with non-zero exit when guardrails are violated",
    )
    args = parser.parse_args()

    with open(args.baseline, encoding="utf-8") as baseline_file:
        baseline_config: dict[str, Any] = json.load(baseline_file)

    scaling_points = [1_000, 10_000] if args.mode == "quick" else [1_000, 10_000, 100_000]

    started = time.perf_counter()
    core_metrics = benchmark_core_operations(replay_batch_size=args.replay_batch_size)
    scaling_metrics = benchmark_scaling(
        event_counts=scaling_points,
        replay_batch_size=args.replay_batch_size,
        workdir=args.workdir,
    )
    elapsed_seconds = time.perf_counter() - started

    failures = enforce_guardrails(
        core_metrics,
        scaling_metrics,
        baseline_config=baseline_config,
    )

    report = {
        "mode": args.mode,
        "elapsed_seconds": elapsed_seconds,
        "core_metrics_ms": core_metrics,
        "scaling_metrics": scaling_metrics,
        "failures": failures,
    }

    report_text = json.dumps(report, indent=2, sort_keys=True)
    print(report_text)

    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report_text + "\n", encoding="utf-8")

    if failures and args.enforce:
        raise SystemExit("Performance guardrail failures:\n- " + "\n- ".join(failures))


if __name__ == "__main__":
    main()
