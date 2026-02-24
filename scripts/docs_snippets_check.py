"""Smoke-check documented CLI snippets from README/demo docs."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TRACE_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"


def _run(command: list[str]) -> str:
    result = subprocess.run(
        command,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        joined = " ".join(command)
        raise SystemExit(
            f"Snippet command failed ({result.returncode}): {joined}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    return result.stdout


def _assert_trace_json(payload: str, *, include_payload: bool) -> None:
    parsed = json.loads(payload)
    if not isinstance(parsed, list) or not parsed:
        raise SystemExit("dump-trace output must be a non-empty JSON array")

    first = parsed[0]
    if not isinstance(first, dict):
        raise SystemExit("dump-trace event rows must be JSON objects")

    has_payload = "payload" in first
    if include_payload and not has_payload:
        raise SystemExit("Expected payload field in --include-payload output")
    if not include_payload and has_payload:
        raise SystemExit("Unexpected payload field in default dump-trace output")


def main() -> None:
    parser = argparse.ArgumentParser(description="Smoke-check documented CLI snippets")
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        default=Path(".tmp") / "docs-snippets",
        help="Directory for snippet smoke artifacts",
    )
    parser.add_argument(
        "--trace-id",
        default=DEFAULT_TRACE_ID,
        help="Trace ID from demo fixture",
    )
    args = parser.parse_args()

    artifact_dir = args.artifact_dir
    if not artifact_dir.is_absolute():
        artifact_dir = REPO_ROOT / artifact_dir
    artifact_dir = artifact_dir.resolve()
    if artifact_dir.exists():
        shutil.rmtree(artifact_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)

    db_path = artifact_dir / "showcase.db"
    output_path = artifact_dir / "showcase.md"

    # README/demo snippets: build DB-backed showcase demo first.
    _run(
        [
            sys.executable,
            str(REPO_ROOT / "demo" / "run_demo.py"),
            "--db",
            str(db_path),
            "--output",
            str(output_path),
            "--force",
        ]
    )

    replay_output = _run(
        [sys.executable, "-m", "decisiongraph", "replay", str(db_path)]
    )
    if "Projection digests after replay" not in replay_output:
        raise SystemExit("replay output missing digest summary marker")

    trace_default = _run(
        [
            sys.executable,
            "-m",
            "decisiongraph",
            "dump-trace",
            str(db_path),
            args.trace_id,
        ]
    )
    _assert_trace_json(trace_default, include_payload=False)

    trace_with_payload = _run(
        [
            sys.executable,
            "-m",
            "decisiongraph",
            "dump-trace",
            str(db_path),
            args.trace_id,
            "--include-payload",
        ]
    )
    _assert_trace_json(trace_with_payload, include_payload=True)

    print(f"Docs snippet smoke checks passed. Artifacts: {artifact_dir}")


if __name__ == "__main__":
    main()
