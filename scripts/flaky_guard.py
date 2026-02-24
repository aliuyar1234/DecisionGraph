"""Repeated-run flakiness guard for CI.

Runs the same command multiple times and fails if observed failures exceed
the configured maximum failure rate.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]


def _tail(text: str, *, max_chars: int = 1200) -> str:
    if len(text) <= max_chars:
        return text
    return text[-max_chars:]


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repeated-run flakiness guard")
    parser.add_argument(
        "--runs",
        type=int,
        default=5,
        help="Number of repeated command runs",
    )
    parser.add_argument(
        "--max-failure-rate",
        type=float,
        default=0.0,
        help="Maximum allowed failure ratio in [0, 1]",
    )
    parser.add_argument(
        "--stop-on-first-failure",
        action="store_true",
        help="Abort early after the first failure",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Command to run repeatedly. Use '-- <cmd ...>'",
    )
    args = parser.parse_args()
    if args.runs <= 0:
        raise SystemExit("--runs must be > 0")
    if args.max_failure_rate < 0 or args.max_failure_rate > 1:
        raise SystemExit("--max-failure-rate must be between 0 and 1")

    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        raise SystemExit("No command provided. Use: flaky_guard.py -- <cmd ...>")
    return args


def main() -> None:
    args = _parse_args()

    failures = 0
    attempts: list[dict[str, Any]] = []

    for run in range(1, args.runs + 1):
        started = time.perf_counter()
        result = subprocess.run(  # noqa: S603
            args.command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        elapsed_seconds = time.perf_counter() - started

        attempt: dict[str, Any] = {
            "run": run,
            "returncode": result.returncode,
            "elapsed_seconds": elapsed_seconds,
        }
        if result.returncode != 0:
            failures += 1
            attempt["stdout_tail"] = _tail(result.stdout)
            attempt["stderr_tail"] = _tail(result.stderr)

        attempts.append(attempt)
        print(
            f"Run {run}/{args.runs}: returncode={result.returncode} "
            f"elapsed={elapsed_seconds:.2f}s"
        )

        if result.returncode != 0 and args.stop_on_first_failure:
            break

    runs_executed = len(attempts)
    failure_rate = failures / runs_executed
    report = {
        "command": args.command,
        "runs_configured": args.runs,
        "runs_executed": runs_executed,
        "failures": failures,
        "failure_rate": failure_rate,
        "max_failure_rate": args.max_failure_rate,
        "attempts": attempts,
    }

    print(json.dumps(report, indent=2, sort_keys=True))

    if failure_rate > args.max_failure_rate:
        raise SystemExit(
            "Flaky guard failed: "
            f"failure_rate={failure_rate:.3f} > max_failure_rate={args.max_failure_rate:.3f}"
        )


if __name__ == "__main__":
    main()
