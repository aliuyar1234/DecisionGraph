defmodule DecisionGraph.Api.WorkflowStudio do
  @moduledoc false

  alias DecisionGraph.Api.Workflows

  @spec list_templates(keyword()) ::
          {:ok, [map()]} | {:error, DecisionGraph.Api.HttpError.t()}
  def list_templates(opts \\ []) do
    Workflows.list_templates(opts)
  end

  @spec overview(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def overview(trace_id, params \\ %{}, opts \\ []) do
    Workflows.simulate_trace_review(trace_id, params, opts)
  end

  @spec start_review(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def start_review(trace_id, attrs, opts \\ []) do
    Workflows.start_trace_review(trace_id, attrs, opts)
  end
end
