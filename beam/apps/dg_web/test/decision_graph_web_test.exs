defmodule DecisionGraphWebTest do
  use ExUnit.Case, async: true

  test "endpoint configuration exposes the configured port" do
    config = DecisionGraphWeb.Endpoint.config(:http)
    assert Keyword.get(config, :port) == 4102
  end
end
