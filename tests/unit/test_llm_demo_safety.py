"""Safety-focused tests for LLM demo output defaults."""

from __future__ import annotations

import runpy
from collections.abc import Callable
from pathlib import Path
from typing import cast

REPO_ROOT = Path(__file__).resolve().parents[2]


def _load_helpers() -> tuple[Callable[[str], str], Callable[..., None]]:
    module = runpy.run_path(str(REPO_ROOT / "demo" / "run_llm_demo.py"), run_name="__test__")
    sanitize_text = cast(Callable[[str], str], module["sanitize_text"])
    emit_skip_report = cast(Callable[..., None], module["emit_skip_report"])
    return sanitize_text, emit_skip_report


def test_sanitize_text_redacts_forbidden_substrings_case_insensitive() -> None:
    sanitize_text, _ = _load_helpers()
    assert sanitize_text("reason=contains Password=super-secret") == "[REDACTED]"


def test_sanitize_text_trims_safe_values() -> None:
    sanitize_text, _ = _load_helpers()
    assert sanitize_text("  policy-compliant summary  ") == "policy-compliant summary"


def test_emit_skip_report_marks_status_and_omits_raw_payload(tmp_path: Path) -> None:
    _, emit_skip_report = _load_helpers()
    output_path = tmp_path / "llm_output.md"

    emit_skip_report(
        output_path,
        backend="ollama",
        model_label="missing-model",
        reason="Model unavailable",
    )

    report = output_path.read_text(encoding="utf-8")
    assert "- Status: skipped" in report
    assert "## Raw LLM Output" in report
    assert "[skipped]" in report
