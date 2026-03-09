defmodule DecisionGraph.Api.ConsoleSupportTest do
  use ExUnit.Case, async: true

  alias DecisionGraph.Api.ConsoleSupport

  test "normalize_positive_limit clamps and falls back cleanly" do
    assert ConsoleSupport.normalize_positive_limit(99, 8, 12) == 12
    assert ConsoleSupport.normalize_positive_limit("7", 8, 12) == 7
    assert ConsoleSupport.normalize_positive_limit("nope", 8, 12) == 8
  end

  test "precedent_query drops blank values" do
    summary = %{
      "primary_entity_id" => "acct-1",
      "primary_entity_type" => "account",
      "outcome" => ""
    }

    policy = %{"policy_id" => "discount-cap", "policy_version" => nil}

    assert ConsoleSupport.precedent_query(summary, policy) == %{
             "entity_id" => "acct-1",
             "entity_type" => "account",
             "limit" => 6,
             "policy_id" => "discount-cap"
           }
  end

  test "trace_policy returns the latest policy payload with stringified keys" do
    trace = %{
      data: %{
        "events" => [
          %{"event_type" => "InputObserved", "payload" => %{}},
          %{
            "event_type" => "PolicyEvaluated",
            "policy" => %{policy_id: "discount-cap", policy_version: "2026.03"}
          }
        ]
      }
    }

    assert ConsoleSupport.trace_policy(trace) == %{
             "policy_id" => "discount-cap",
             "policy_version" => "2026.03"
           }
  end
end
