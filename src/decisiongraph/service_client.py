"""Explicit stdlib-only client for the BEAM HTTP service."""

from __future__ import annotations

import json
from collections.abc import Mapping
from typing import Any
from urllib import error, parse, request

QueryValue = str | int | list[str]


class DecisionGraphServiceError(Exception):
    """Raised when the BEAM HTTP service returns an error response."""

    def __init__(
        self,
        message: str,
        *,
        status_code: int | None = None,
        details: dict[str, Any] | None = None,
        body: str | None = None,
        code: str | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.status_code = status_code
        self.details = details or {}
        self.body = body


class DecisionGraphServiceClient:
    """Client for the authenticated BEAM `/api/v1` surface."""

    DEFAULT_TIMEOUT_SECONDS = 5.0

    def __init__(
        self,
        *,
        base_url: str,
        bearer_token: str,
        tenant_id: str,
        timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
    ) -> None:
        self._base_url = _normalize_required(base_url, "base_url").rstrip("/")
        self._bearer_token = _normalize_required(bearer_token, "bearer_token")
        self._tenant_id = _normalize_required(tenant_id, "tenant_id")
        if timeout_seconds <= 0:
            raise ValueError("timeout_seconds must be positive")
        self._timeout_seconds = timeout_seconds

    def get_healthz(self) -> dict[str, Any]:
        return self._request_json("GET", "/api/healthz", include_auth=False, include_tenant=False)

    def append_event(self, event: dict[str, Any]) -> dict[str, Any]:
        return self._request_json("POST", "/api/v1/events", body=event)

    def get_trace(self, trace_id: str) -> dict[str, Any]:
        encoded_trace_id = parse.quote(_normalize_required(trace_id, "trace_id"), safe="")
        return self._request_json("GET", f"/api/v1/traces/{encoded_trace_id}")

    def get_projection_health(self) -> dict[str, Any]:
        return self._request_json("GET", "/api/v1/projections/health")

    def get_context_subgraph(
        self,
        *,
        node_type: str,
        node_id: str,
        max_depth: int = 1,
        max_nodes: int | None = None,
        max_edges: int | None = None,
        edge_types: list[str] | None = None,
        node_types: list[str] | None = None,
    ) -> dict[str, Any]:
        params: dict[str, QueryValue] = {
            "node_type": _normalize_required(node_type, "node_type"),
            "node_id": _normalize_required(node_id, "node_id"),
            "max_depth": max_depth,
        }
        if max_nodes is not None:
            params["max_nodes"] = max_nodes
        if max_edges is not None:
            params["max_edges"] = max_edges
        if edge_types:
            params["edge_types"] = edge_types
        if node_types:
            params["node_types"] = node_types
        return self._request_json("GET", "/api/v1/graph/context", query=params)

    def list_node_edges(
        self,
        *,
        node_type: str,
        node_id: str,
        direction: str = "both",
        limit: int = 100,
        cursor_edge_key: str | None = None,
        cursor_log_seq: int | None = None,
    ) -> dict[str, Any]:
        params: dict[str, QueryValue] = {
            "node_type": _normalize_required(node_type, "node_type"),
            "node_id": _normalize_required(node_id, "node_id"),
            "direction": _normalize_required(direction, "direction"),
            "limit": limit,
        }
        if cursor_edge_key is not None:
            params["cursor_edge_key"] = cursor_edge_key
        if cursor_log_seq is not None:
            params["cursor_log_seq"] = cursor_log_seq
        return self._request_json("GET", "/api/v1/graph/edges", query=params)

    def find_precedents(
        self,
        *,
        policy_id: str | None = None,
        policy_version: str | None = None,
        entity_type: str | None = None,
        entity_id: str | None = None,
        outcome: str | None = None,
        limit: int = 100,
    ) -> dict[str, Any]:
        params: dict[str, QueryValue] = {
            key: value
            for key, value in {
                "policy_id": policy_id,
                "policy_version": policy_version,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "outcome": outcome,
                "limit": limit,
            }.items()
            if value is not None
        }
        return self._request_json("GET", "/api/v1/precedents", query=params)

    def start_replay(
        self,
        *,
        projection: str,
        mode: str,
        reason: str,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "projection": _normalize_required(projection, "projection"),
            "mode": _normalize_required(mode, "mode"),
            "reason": _normalize_required(reason, "reason"),
        }
        if metadata:
            payload["metadata"] = metadata
        return self._request_json("POST", "/api/v1/admin/replays", body=payload)

    def get_replay_status(self, job_id: str) -> dict[str, Any]:
        encoded_job_id = parse.quote(_normalize_required(job_id, "job_id"), safe="")
        return self._request_json("GET", f"/api/v1/admin/replays/{encoded_job_id}")

    def cancel_replay(self, job_id: str) -> dict[str, Any]:
        encoded_job_id = parse.quote(_normalize_required(job_id, "job_id"), safe="")
        return self._request_json("POST", f"/api/v1/admin/replays/{encoded_job_id}/cancel")

    def export_workflow(self, workflow_id: str) -> dict[str, Any]:
        encoded_workflow_id = parse.quote(
            _normalize_required(workflow_id, "workflow_id"),
            safe="",
        )
        return self._request_json(
            "GET",
            f"/api/v1/admin/workflows/{encoded_workflow_id}/export",
        )

    def _request_json(
        self,
        method: str,
        path: str,
        *,
        body: dict[str, Any] | None = None,
        query: Mapping[str, QueryValue] | None = None,
        include_auth: bool = True,
        include_tenant: bool = True,
    ) -> dict[str, Any]:
        url = _join_url(self._base_url, path, query)
        headers = {"accept": "application/json"}
        if include_auth:
            headers["authorization"] = f"Bearer {self._bearer_token}"
        if include_tenant:
            headers["x-tenant-id"] = self._tenant_id

        payload: bytes | None = None
        if body is not None:
            headers["content-type"] = "application/json"
            payload = json.dumps(body, separators=(",", ":"), sort_keys=True).encode("utf-8")

        req = request.Request(url, data=payload, headers=headers, method=method)
        try:
            with request.urlopen(req, timeout=self._timeout_seconds) as response:
                raw_body = response.read().decode("utf-8")
                return _decode_json_body(raw_body, response.status)
        except error.HTTPError as exc:
            raw_body = exc.read().decode("utf-8", errors="replace")
            raise _service_error_from_response(raw_body, exc.code) from exc
        except error.URLError as exc:
            raise DecisionGraphServiceError(
                f"Failed to reach DecisionGraph service: {exc.reason}"
            ) from exc


def _normalize_required(value: str, field: str) -> str:
    if value is None:
        raise ValueError(f"{field} is required")
    normalized = str(value).strip()
    if not normalized:
        raise ValueError(f"{field} is required")
    return normalized


def _join_url(
    base_url: str,
    path: str,
    query: Mapping[str, QueryValue] | None,
) -> str:
    encoded_query = ""
    if query:
        encoded_query = parse.urlencode(query, doseq=True)
    url = f"{base_url}{path}"
    if encoded_query:
        url = f"{url}?{encoded_query}"
    return url


def _decode_json_body(raw_body: str, status_code: int) -> dict[str, Any]:
    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise DecisionGraphServiceError(
            f"DecisionGraph service returned non-JSON body for HTTP {status_code}",
            status_code=status_code,
            body=raw_body,
        ) from exc

    if not isinstance(payload, dict):
        raise DecisionGraphServiceError(
            f"DecisionGraph service returned non-object JSON for HTTP {status_code}",
            status_code=status_code,
            body=raw_body,
        )
    return payload


def _service_error_from_response(raw_body: str, status_code: int) -> DecisionGraphServiceError:
    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError:
        return DecisionGraphServiceError(
            f"DecisionGraph service returned HTTP {status_code}",
            status_code=status_code,
            body=raw_body,
        )

    if isinstance(payload, dict) and isinstance(payload.get("error"), dict):
        error_payload = payload["error"]
        code = error_payload.get("code")
        message = error_payload.get("message", f"DecisionGraph service returned HTTP {status_code}")
        details = error_payload.get("details")
        return DecisionGraphServiceError(
            message,
            status_code=status_code,
            code=code if isinstance(code, str) else None,
            details=details if isinstance(details, dict) else None,
            body=raw_body,
        )

    return DecisionGraphServiceError(
        f"DecisionGraph service returned HTTP {status_code}",
        status_code=status_code,
        body=raw_body,
    )


__all__ = ["DecisionGraphServiceClient", "DecisionGraphServiceError"]
