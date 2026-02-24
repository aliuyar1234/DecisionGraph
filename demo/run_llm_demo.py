"""Run a real local LLM decision trace and persist it via DecisionGraph."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

from decisiongraph import DecisionGraph
from decisiongraph.domain.events import (
    EVENT_TYPE_ACTION_COMMITTED,
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_INPUT_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
)
from decisiongraph.domain.types import ActorRef, EntityRef, SourceRef
from decisiongraph.domain.validation import FORBIDDEN_SUBSTRINGS

DEFAULT_MODEL_CANDIDATES = [
    Path("D:/models/qwen-1.5b"),
    Path("D:/models/Qwen2.5-7B-Instruct"),
]

ALLOWED_DECISIONS = {"approve", "deny", "require_exception"}


def resolve_default_model() -> Path | None:
    for candidate in DEFAULT_MODEL_CANDIDATES:
        if candidate.exists():
            return candidate
    return None


def build_prompt(instruction: str, user_case: str) -> str:
    return f"System: {instruction}\nUser: {user_case}\nAssistant:"


def extract_json(text: str) -> dict | None:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                return None
    return None


def sanitize_text(value: str) -> str:
    lowered = value.lower()
    for pattern in FORBIDDEN_SUBSTRINGS:
        if pattern.lower() in lowered:
            return "[REDACTED]"
    return value.strip()


def decide_from_text(text: str) -> str:
    lowered = text.lower()
    if "cap" in lowered and "20" in lowered and "10" in lowered:
        return "require_exception"
    if "exception" in lowered or "escalat" in lowered:
        return "require_exception"
    if "deny" in lowered or "reject" in lowered:
        return "deny"
    return "approve"


def run_ollama(model: str, prompt: str) -> str:
    result = subprocess.run(
        ["ollama", "run", model, prompt],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    )
    return result.stdout.strip()


def run_transformers(
    model_path: Path,
    instruction: str,
    user_case: str,
    max_new_tokens: int,
    temperature: float,
) -> str:
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32

    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        torch_dtype=dtype,
        trust_remote_code=True,
        device_map="auto" if device == "cuda" else None,
    )
    if device != "cuda":
        model.to(device)
    model.eval()

    if hasattr(tokenizer, "apply_chat_template"):
        messages = [
            {"role": "system", "content": instruction},
            {"role": "user", "content": user_case},
        ]
        render = tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
    else:
        render = build_prompt(instruction, user_case)

    inputs = tokenizer(render, return_tensors="pt")
    inputs = {key: value.to(device) for key, value in inputs.items()}

    generation = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=temperature > 0,
        temperature=temperature if temperature > 0 else None,
        pad_token_id=tokenizer.eos_token_id,
    )

    output_ids = generation[0][inputs["input_ids"].shape[1] :]
    text = tokenizer.decode(output_ids, skip_special_tokens=True)
    return text.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run an LLM-backed demo trace")
    parser.add_argument("--backend", choices=["auto", "transformers", "ollama"], default="auto")
    parser.add_argument("--model-path", type=Path, default=None)
    parser.add_argument("--ollama-model", type=str, default=None)
    parser.add_argument("--max-new-tokens", type=int, default=128)
    parser.add_argument("--temperature", type=float, default=0.2)
    parser.add_argument("--db", type=Path, default=Path("demo") / "llm_demo.db")
    parser.add_argument("--output", type=Path, default=Path("demo") / "llm_output.md")
    args = parser.parse_args()

    model_path = args.model_path or resolve_default_model()
    backend = args.backend

    if backend == "auto":
        if args.ollama_model:
            backend = "ollama"
        elif model_path:
            backend = "transformers"
        else:
            raise SystemExit("No model found. Provide --model-path or --ollama-model.")

    instruction = (
        "You are a strict JSON generator. "
        "Return ONLY valid JSON with keys: decision, summary. "
        f"Allowed decisions: {sorted(ALLOWED_DECISIONS)}. "
        "Summary must be <= 30 words. No PII, no secrets."
    )

    user_case = (
        "Customer requested 20% renewal discount. Policy cap is 10%. "
        "Account had 3 SEV-1 incidents in 90 days. "
        "Should we approve, deny, or require an exception?"
    )

    prompt = build_prompt(instruction, user_case)
    if backend == "ollama":
        if not args.ollama_model:
            raise SystemExit("--ollama-model is required for ollama backend.")
        raw_response = run_ollama(args.ollama_model, prompt)
    else:
        if not model_path:
            raise SystemExit("Model path not found. Provide --model-path.")
        raw_response = run_transformers(
            model_path,
            instruction,
            user_case,
            max_new_tokens=args.max_new_tokens,
            temperature=args.temperature,
        )

    data = extract_json(raw_response) or {}
    decision = data.get("decision")
    summary = data.get("summary")

    if decision not in ALLOWED_DECISIONS:
        decision = decide_from_text(f"{raw_response} {user_case}")

    if not summary:
        summary = (
            "LLM recommended "
            f"'{decision}' based on policy cap and incident history."
        )

    summary = sanitize_text(summary)
    if len(summary.split()) > 30:
        summary = " ".join(summary.split()[:30])

    # Persist trace
    args.db.parent.mkdir(parents=True, exist_ok=True)
    dg = DecisionGraph(str(args.db))

    source = SourceRef(producer_id="llm-demo", system="local")
    actor = ActorRef(actor_type="agent", actor_id=f"llm-{backend}")
    account = EntityRef(entity_type="account", entity_id="acct-123", system="crm")

    trace_id = dg.start_trace(
        workflow="llm_discount_review",
        title="LLM discount decision demo",
        primary_entity=account,
        source=source,
        actor=actor,
    )

    dg.append_event(
        trace_id=trace_id,
        event_type=EVENT_TYPE_INPUT_OBSERVED,
        payload={
            "input_id": "input:discount_request",
            "source": {
                "system": "crm",
                "object_type": "discount_request",
                "object_id": "req-001",
            },
            "facts": [
                {"key": "requested_discount", "value": {"type": "percent", "value": "20"}},
                {"key": "sev1_last_90d", "value": {"type": "int", "value": "3"}},
                {"key": "policy_cap", "value": {"type": "percent", "value": "10"}},
            ],
        },
        source=source,
        actor=actor,
    )

    dg.append_event(
        trace_id=trace_id,
        event_type=EVENT_TYPE_POLICY_EVALUATED,
        payload={
            "policy": {"policy_id": "discount_cap", "policy_version": "1.0"},
            "inputs": ["input:discount_request"],
            "decision": decision,
            "explanation": {"summary": summary},
        },
        source=source,
        actor=actor,
    )

    if decision == "require_exception":
        dg.append_event(
            trace_id=trace_id,
            event_type=EVENT_TYPE_EXCEPTION_REQUESTED,
            payload={
                "exception_id": "exc:discount_over_cap",
                "policy": {"policy_id": "discount_cap", "policy_version": "1.0"},
                "reason": summary or "Exception required due to policy cap.",
            },
            source=source,
            actor=actor,
        )

    action_id = f"act:discount:{trace_id}"
    action_type = "apply_discount" if decision == "approve" else "escalate_discount"
    dg.append_event(
        trace_id=trace_id,
        event_type=EVENT_TYPE_ACTION_PROPOSED,
        payload={
            "action_id": action_id,
            "action_type": action_type,
            "target_entity": {"entity_type": "account", "entity_id": "acct-123"},
            "target_system": "salesforce",
            "changes": [{"field": "discount", "value": "20%"}],
        },
        source=source,
        actor=actor,
    )

    if decision == "approve":
        dg.append_event(
            trace_id=trace_id,
            event_type=EVENT_TYPE_ACTION_COMMITTED,
            payload={"action_id": action_id, "status": "success"},
            source=source,
            actor=actor,
        )

    outcome = "success" if decision == "approve" else "abandoned"
    if decision == "deny":
        outcome = "failure"

    dg.finish_trace(trace_id, outcome=outcome, source=source, actor=actor, summary=summary)

    events = dg.get_trace_events(trace_id)

    report = [
        "# LLM Demo Output",
        "",
        f"- Backend: {backend}",
        f"- Model: {args.ollama_model or model_path}",
        f"- Trace ID: {trace_id}",
        f"- Decision: {decision}",
        f"- Outcome: {outcome}",
        f"- Events: {len(events)}",
        f"- Summary: {summary}",
        "",
        "## Raw LLM Output",
        "```",
        raw_response.strip(),
        "```",
    ]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()
