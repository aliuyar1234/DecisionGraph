"""Tests for the explicit BEAM HTTP service client."""

from __future__ import annotations

import io
import json
from urllib.error import HTTPError

import pytest

from decisiongraph.service_client import (
    DecisionGraphServiceClient,
    DecisionGraphServiceError,
)


class _FakeResponse:
    def __init__(self, status: int, payload: dict[str, object]) -> None:
        self.status = status
        self._payload = json.dumps(payload).encode("utf-8")

    def __enter__(self) -> _FakeResponse:
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None

    def read(self) -> bytes:
        return self._payload


def test_get_trace_includes_auth_and_tenant_headers(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    def fake_urlopen(req, timeout: float):
        captured["url"] = req.full_url
        captured["headers"] = {
            key.lower(): value for key, value in dict(req.header_items()).items()
        }
        captured["timeout"] = timeout
        return _FakeResponse(200, {"data": {"summary": {"trace_id": "trace-1"}}})

    monkeypatch.setattr("decisiongraph.service_client.request.urlopen", fake_urlopen)

    client = DecisionGraphServiceClient(
        base_url="http://localhost:4100",
        bearer_token="reader-token",
        tenant_id="tenant-a",
    )
    payload = client.get_trace("trace-1")

    assert payload["data"]["summary"]["trace_id"] == "trace-1"
    assert captured["url"] == "http://localhost:4100/api/v1/traces/trace-1"
    assert captured["timeout"] == client.DEFAULT_TIMEOUT_SECONDS
    assert captured["headers"] == {
        "accept": "application/json",
        "authorization": "Bearer reader-token",
        "x-tenant-id": "tenant-a",
    }


def test_healthz_omits_authenticated_headers(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    def fake_urlopen(req, timeout: float):
        captured["headers"] = {
            key.lower(): value for key, value in dict(req.header_items()).items()
        }
        captured["timeout"] = timeout
        return _FakeResponse(200, {"deployment_env": "test"})

    monkeypatch.setattr("decisiongraph.service_client.request.urlopen", fake_urlopen)

    client = DecisionGraphServiceClient(
        base_url="http://localhost:4100",
        bearer_token="reader-token",
        tenant_id="tenant-a",
    )
    payload = client.get_healthz()

    assert payload["deployment_env"] == "test"
    assert captured["headers"] == {"accept": "application/json"}
    assert captured["timeout"] == client.DEFAULT_TIMEOUT_SECONDS


def test_context_subgraph_encodes_query_lists(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    def fake_urlopen(req, timeout: float):
        captured["url"] = req.full_url
        captured["timeout"] = timeout
        return _FakeResponse(200, {"data": {"nodes": [], "edges": []}})

    monkeypatch.setattr("decisiongraph.service_client.request.urlopen", fake_urlopen)

    client = DecisionGraphServiceClient(
        base_url="http://localhost:4100",
        bearer_token="reader-token",
        tenant_id="tenant-a",
    )
    client.get_context_subgraph(
        node_type="trace",
        node_id="trace-1",
        max_depth=2,
        edge_types=["caused_by", "references"],
        node_types=["trace", "policy"],
    )

    assert (
        captured["url"]
        == "http://localhost:4100/api/v1/graph/context?"
        "node_type=trace&node_id=trace-1&max_depth=2&"
        "edge_types=caused_by&edge_types=references&node_types=trace&node_types=policy"
    )
    assert captured["timeout"] == client.DEFAULT_TIMEOUT_SECONDS


def test_http_errors_raise_structured_service_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_urlopen(req, timeout: float):
        assert timeout == 5.0
        raise HTTPError(
            req.full_url,
            409,
            "Conflict",
            hdrs=None,
            fp=io.BytesIO(
                json.dumps(
                    {
                        "error": {
                            "code": "projection_out_of_date",
                            "message": "projection catch-up required",
                            "details": {"projection": "trace_summary"},
                        }
                    }
                ).encode("utf-8")
            ),
        )

    monkeypatch.setattr("decisiongraph.service_client.request.urlopen", fake_urlopen)

    client = DecisionGraphServiceClient(
        base_url="http://localhost:4100",
        bearer_token="reader-token",
        tenant_id="tenant-a",
    )

    with pytest.raises(DecisionGraphServiceError) as exc_info:
        client.get_trace("trace-1")

    error = exc_info.value
    assert error.status_code == 409
    assert error.code == "projection_out_of_date"
    assert error.details == {"projection": "trace_summary"}
    assert str(error) == "projection catch-up required"


def test_invalid_timeout_is_rejected() -> None:
    with pytest.raises(ValueError, match="timeout_seconds must be positive"):
        DecisionGraphServiceClient(
            base_url="http://localhost:4100",
            bearer_token="reader-token",
            tenant_id="tenant-a",
            timeout_seconds=0,
        )
