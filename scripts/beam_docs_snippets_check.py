"""Smoke-check documented BEAM install and demo snippets."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
BEAM_ROOT = REPO_ROOT / "beam"
MIX_COMMAND = ["mix.bat"] if sys.platform == "win32" else ["mix"]

REQUIRED_SNIPPETS = {
    REPO_ROOT / "README.md": [
        "mix dg.demo.seed --output ../.tmp/phase10-demo-report.json",
        "mix dg.release.validate --output ../.tmp/phase10-release-validation.json",
        "mix dg.accounts.bootstrap --output ../.tmp/service-accounts.json",
        "mix release decisiongraph_beam",
    ],
    BEAM_ROOT / "README.md": [
        "mix dg.demo.seed --output ../.tmp/phase10-demo-report.json",
        "mix dg.release.validate --output ../.tmp/phase10-release-validation.json",
        "mix dg.accounts.bootstrap --output ../.tmp/service-accounts.json",
        "mix release decisiongraph_beam",
    ],
    REPO_ROOT / "docs" / "operations" / "SELF_HOSTED_INSTALL.md": [
        "mix dg.accounts.bootstrap --output ../.tmp/service-accounts.json",
        "mix dg.release.validate --output ../.tmp/phase10-release-validation.json",
        "--summary-output ../.tmp/phase10-release-validation.md",
        "--seed-mode reuse",
    ],
    REPO_ROOT / "docs" / "showcase.md": [
        "mix dg.demo.seed --output ../.tmp/phase10-demo-report.json",
        "mix dg.release.validate --output ../.tmp/phase10-release-validation.json",
        "--summary-output ../.tmp/phase10-release-validation.md",
    ],
}


def _run(command: list[str], *, cwd: Path) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
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


def _assert_doc_snippets() -> None:
    missing: list[str] = []
    for path, snippets in REQUIRED_SNIPPETS.items():
        contents = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in contents:
                missing.append(f"{path.relative_to(REPO_ROOT)} :: {snippet}")

    if missing:
        raise SystemExit(
            "BEAM docs snippet coverage is missing expected commands:\n"
            + "\n".join(f"- {entry}" for entry in missing)
        )


def _assert_bootstrap_payload(payload_path: Path) -> None:
    payload = json.loads(payload_path.read_text(encoding="utf-8"))

    operator_console_account_id = payload.get("operator_console_account_id")
    service_accounts = payload.get("service_accounts")

    if not isinstance(operator_console_account_id, str) or not operator_console_account_id:
        raise SystemExit("Generated bootstrap JSON is missing operator_console_account_id")

    if not isinstance(service_accounts, list) or len(service_accounts) != 3:
        raise SystemExit("Generated bootstrap JSON must contain 3 service_accounts entries")

    expected_roles = {"reader", "writer", "admin"}
    actual_roles = {
        role
        for account in service_accounts
        for role in account.get("roles", [])
        if isinstance(role, str)
    }
    if actual_roles != expected_roles:
        raise SystemExit(
            f"Generated bootstrap JSON roles mismatch: expected {expected_roles}, got {actual_roles}"
        )

    for account in service_accounts:
        tokens = account.get("tokens")
        tenant_ids = account.get("tenant_ids")
        if not isinstance(tokens, list) or not tokens or not all(tokens):
            raise SystemExit("Each generated bootstrap account must include non-empty tokens")
        if not isinstance(tenant_ids, list) or "docs-tenant" not in tenant_ids:
            raise SystemExit("Generated bootstrap accounts must include docs-tenant")
        if "release-demo" not in tenant_ids:
            raise SystemExit("Generated bootstrap accounts must include release-demo")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Smoke-check documented BEAM install and demo snippets"
    )
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        default=Path(".tmp") / "beam-docs-snippets",
        help="Directory for generated snippet smoke artifacts",
    )
    args = parser.parse_args()

    artifact_dir = args.artifact_dir
    if not artifact_dir.is_absolute():
        artifact_dir = REPO_ROOT / artifact_dir
    artifact_dir = artifact_dir.resolve()

    if artifact_dir.exists():
        shutil.rmtree(artifact_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)

    _assert_doc_snippets()

    bootstrap_path = artifact_dir / "service-accounts.json"
    _run(
        MIX_COMMAND
        + [
            "dg.accounts.bootstrap",
            "--account-prefix",
            "docs",
            "--tenant-id",
            "docs-tenant",
            "--include-release-demo",
            "--output",
            str(bootstrap_path),
        ],
        cwd=BEAM_ROOT,
    )
    _assert_bootstrap_payload(bootstrap_path)

    print(f"BEAM docs snippet smoke checks passed. Artifacts: {artifact_dir}")


if __name__ == "__main__":
    main()
