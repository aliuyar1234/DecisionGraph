"""Tests for demo path hardening."""

import runpy
from collections.abc import Callable
from pathlib import Path
from typing import cast

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


def _load_resolver(script_name: str) -> tuple[Callable[[Path, str], Path], Path]:
    module = runpy.run_path(str(REPO_ROOT / "demo" / script_name), run_name="__test__")
    resolver = cast(Callable[[Path, str], Path], module["resolve_demo_path"])
    demo_root = cast(Path, module["DEMO_ROOT"])
    return resolver, demo_root


def test_run_demo_resolve_path_accepts_demo_directory_targets() -> None:
    resolver, demo_root = _load_resolver("run_demo.py")
    inside = demo_root / "tmp-security.db"
    assert resolver(inside, "Database") == inside.resolve()


def test_run_demo_resolve_path_rejects_outside_paths() -> None:
    resolver, demo_root = _load_resolver("run_demo.py")
    outside = demo_root.parent / "tmp-security.db"
    with pytest.raises(SystemExit):
        resolver(outside, "Database")


def test_run_llm_demo_resolve_path_rejects_outside_paths() -> None:
    resolver, demo_root = _load_resolver("run_llm_demo.py")
    outside = demo_root.parent / "tmp-security.md"
    with pytest.raises(SystemExit):
        resolver(outside, "Output")
