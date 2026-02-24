"""Run deterministic demo smoke checks for CI and local validation."""

from __future__ import annotations

import argparse
import difflib
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TRACE_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
EXPECTED_OUTPUT_PATH = REPO_ROOT / "demo" / "output.md"


def normalize_text(value: str) -> str:
    normalized = value.replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.rstrip() for line in normalized.split("\n")]
    return "\n".join(lines).strip() + "\n"


def run_command(command: list[str]) -> str:
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
            f"Command failed ({result.returncode}): {joined}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    return result.stdout


def ensure_inside_repo(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    try:
        resolved.relative_to(REPO_ROOT)
    except ValueError as exc:
        raise SystemExit(f"Path must be inside repo: {resolved}") from exc
    return resolved


def assert_output_matches_reference(generated_path: Path) -> None:
    if not EXPECTED_OUTPUT_PATH.exists():
        raise SystemExit(f"Expected reference output missing: {EXPECTED_OUTPUT_PATH}")

    generated = normalize_text(generated_path.read_text(encoding="utf-8"))
    expected = normalize_text(EXPECTED_OUTPUT_PATH.read_text(encoding="utf-8"))
    if generated == expected:
        return

    diff = difflib.unified_diff(
        expected.splitlines(),
        generated.splitlines(),
        fromfile=str(EXPECTED_OUTPUT_PATH),
        tofile=str(generated_path),
        lineterm="",
    )
    diff_preview = "\n".join(list(diff)[:200])
    raise SystemExit(f"Deterministic demo output mismatch:\n{diff_preview}")


def assert_replay_output(output: str) -> None:
    required_markers = (
        "Projection digests after replay:",
        "context_graph:",
        "trace_summary:",
        "precedent_index:",
        "full_projection:",
    )
    missing = [marker for marker in required_markers if marker not in output]
    if missing:
        raise SystemExit(f"Replay output missing expected markers: {', '.join(missing)}")


def assert_trace_dump(output: str) -> list[dict]:
    try:
        payload = json.loads(output)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Trace dump is not valid JSON: {exc}") from exc

    if not isinstance(payload, list) or not payload:
        raise SystemExit("Trace dump must be a non-empty JSON array.")

    first = payload[0]
    if not isinstance(first, dict):
        raise SystemExit("Trace dump items must be JSON objects.")

    for field in ("payload", "source", "actor"):
        if field in first:
            raise SystemExit(
                "Trace dump includes restricted fields without --include-payload."
            )

    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description="Run deterministic demo smoke checks")
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        default=Path(".tmp") / "demo-smoke",
        help="Directory for generated smoke artifacts",
    )
    parser.add_argument(
        "--trace-id",
        default=DEFAULT_TRACE_ID,
        help="Trace id to validate with dump-trace",
    )
    args = parser.parse_args()

    artifact_dir = args.artifact_dir
    if not artifact_dir.is_absolute():
        artifact_dir = REPO_ROOT / artifact_dir
    artifact_dir = ensure_inside_repo(artifact_dir)

    if artifact_dir.exists():
        shutil.rmtree(artifact_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)

    output_memory = artifact_dir / "demo-output.md"
    output_db = artifact_dir / "demo-output-with-db.md"
    db_path = artifact_dir / "demo.db"
    replay_path = artifact_dir / "replay.txt"
    trace_dump_path = artifact_dir / "trace.json"

    run_command(
        [
            sys.executable,
            str(REPO_ROOT / "demo" / "run_demo.py"),
            "--output",
            str(output_memory),
        ]
    )
    assert_output_matches_reference(output_memory)

    run_command(
        [
            sys.executable,
            str(REPO_ROOT / "demo" / "run_demo.py"),
            "--db",
            str(db_path),
            "--output",
            str(output_db),
            "--force",
        ]
    )

    replay_output = run_command(
        [
            sys.executable,
            "-m",
            "decisiongraph",
            "replay",
            str(db_path),
        ]
    )
    replay_path.write_text(replay_output, encoding="utf-8")
    assert_replay_output(replay_output)

    trace_output = run_command(
        [
            sys.executable,
            "-m",
            "decisiongraph",
            "dump-trace",
            str(db_path),
            args.trace_id,
        ]
    )
    trace_dump_path.write_text(trace_output, encoding="utf-8")
    events = assert_trace_dump(trace_output)

    print(
        "Demo smoke checks passed. "
        f"Artifact directory: {artifact_dir} | Trace events validated: {len(events)}"
    )


if __name__ == "__main__":
    main()
