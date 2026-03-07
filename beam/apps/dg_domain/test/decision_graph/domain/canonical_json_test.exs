defmodule DecisionGraph.Domain.CanonicalJsonTest do
  use ExUnit.Case, async: true

  alias DecisionGraph.Domain.CanonicalJson

  test "preserves nil and boolean scalars inside maps and lists" do
    assert CanonicalJson.canonicalize!(%{
             "enabled" => true,
             "items" => [false, nil],
             "maybe" => nil
           }) ==
             "{\"enabled\":true,\"items\":[false,null],\"maybe\":null}"
  end

  test "still stringifies non-boolean atoms for deterministic JSON" do
    assert CanonicalJson.canonicalize!(%{"status" => :open}) == "{\"status\":\"open\"}"
  end
end
