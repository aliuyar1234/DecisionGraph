"""Validate README coverage badge health and Codecov coverage value."""

from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse
from urllib.request import Request, urlopen

REPO_ROOT = Path(__file__).resolve().parents[1]
UNKNOWN_TOKENS = ("unknown", "n/a", "inaccessible")


def fetch_text(url: str, *, attempts: int = 3, timeout_seconds: int = 20) -> str:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        request = Request(url, headers={"User-Agent": "decisiongraph-ci/1.0"})
        try:
            with urlopen(request, timeout=timeout_seconds) as response:  # noqa: S310
                return response.read().decode("utf-8", errors="replace")
        except Exception as exc:  # pragma: no cover - network variability
            last_error = exc
            if attempt < attempts:
                time.sleep(attempt)

    raise SystemExit(f"Failed to fetch URL after {attempts} attempts: {url}\n{last_error}")


def extract_coverage_badge_url(readme_text: str) -> str | None:
    match = re.search(r"\[!\[Coverage\]\(([^)]+)\)\]\(([^)]+)\)", readme_text)
    if not match:
        return None
    return match.group(1)


def ensure_badge_is_numeric(badge_svg: str) -> None:
    lowered = badge_svg.lower()
    if any(token in lowered for token in UNKNOWN_TOKENS):
        raise SystemExit("Coverage badge resolved to unknown/inaccessible state.")

    has_percent = re.search(r"\d+(?:\.\d+)?(?:%|&#37;)", badge_svg) is not None
    if not has_percent:
        raise SystemExit("Coverage badge does not include a numeric percentage.")


def resolve_coverage_from_api(badge_url: str) -> float:
    parsed = urlparse(badge_url)
    params = parse_qs(parsed.query)
    json_urls = params.get("url")
    if not json_urls:
        raise SystemExit(
            "Coverage badge URL must include a JSON source URL for health checks."
        )

    data_url = unquote(json_urls[0])
    payload = fetch_text(data_url)
    try:
        data: dict[str, Any] = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Coverage API did not return valid JSON: {data_url}") from exc

    totals = data.get("totals")
    if not isinstance(totals, dict):
        raise SystemExit("Coverage API JSON does not include 'totals'.")
    coverage = totals.get("coverage")
    if not isinstance(coverage, (int, float)):
        raise SystemExit("Coverage API JSON does not include numeric totals.coverage.")
    return float(coverage)


def main() -> None:
    parser = argparse.ArgumentParser(description="Check README coverage badge health")
    parser.add_argument(
        "--readme",
        type=Path,
        default=REPO_ROOT / "README.md",
        help="Path to README file containing coverage badge",
    )
    args = parser.parse_args()

    readme_text = args.readme.read_text(encoding="utf-8")
    badge_url = extract_coverage_badge_url(readme_text)
    if badge_url is None:
        print("Coverage badge not present in README.md; skipping badge health check.")
        return

    badge_svg = fetch_text(badge_url)
    ensure_badge_is_numeric(badge_svg)

    coverage = resolve_coverage_from_api(badge_url)
    print(f"Coverage badge healthy. Codecov totals.coverage={coverage:.2f}%")


if __name__ == "__main__":
    main()
