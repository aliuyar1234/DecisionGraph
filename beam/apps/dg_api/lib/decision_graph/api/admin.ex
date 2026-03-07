defmodule DecisionGraph.Api.Admin do
  @moduledoc false

  alias DecisionGraph.Api
  alias DecisionGraph.Api.Audit
  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Api.HttpError
  alias DecisionGraph.Api.ServiceAccount
  alias DecisionGraph.Error

  @spec projection_health(keyword()) :: {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def projection_health(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    projector = Api.projector_module()

    try do
      {:ok, projector.projection_health(tenant_id: tenant_id)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec list_runs(keyword()) :: {:ok, [map()]} | {:error, DecisionGraph.Api.HttpError.t()}
  def list_runs(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    projector = Api.projector_module()

    try do
      {:ok, projector.list_runs(tenant_id: tenant_id)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec list_failures(keyword()) :: {:ok, [map()]} | {:error, DecisionGraph.Api.HttpError.t()}
  def list_failures(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    projector = Api.projector_module()

    try do
      {:ok, projector.list_failures(tenant_id: tenant_id)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec start_replay(map(), keyword()) :: {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def start_replay(attrs, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    actor = Keyword.get(opts, :actor)
    request_id = Keyword.get(opts, :request_id)
    projector = Api.projector_module()

    try do
      mode = normalize_mode(value(attrs, :mode, "catch_up"))
      projection = normalize_projection(value(attrs, :projection))
      reason = required_reason(attrs)
      permission = permission_for_mode(mode)

      with :ok <- authorize(actor, permission),
           :ok <- ensure_mode_enabled(mode) do
        replay_opts = replay_opts(attrs, tenant_id, actor, request_id, reason)

        result =
          try do
            case mode do
              "catch_up" -> projector.replay(projection, replay_opts)
              "rebuild" -> projector.rebuild(projection, replay_opts)
            end
          rescue
            error -> {:error, Errors.from_exception(error)}
          end

        case result do
          {:ok, run} ->
            audit(:start_replay, :accepted,
              account_id: actor && actor.account_id,
              job_id: field(run, :job_id),
              mode: mode,
              permission: permission,
              projection: projection,
              reason: reason,
              request_id: request_id,
              tenant_id: tenant_id
            )

            {:ok, run}

          {:error, error} ->
            audit(:start_replay, :rejected,
              account_id: actor && actor.account_id,
              mode: mode,
              permission: permission,
              projection: projection,
              reason: field(error, :message),
              request_id: request_id,
              tenant_id: tenant_id
            )

            {:error, normalize_error(error)}
        end
      else
        {:error, error} ->
          audit(:start_replay, :rejected,
            account_id: actor && actor.account_id,
            mode: mode,
            permission: permission,
            projection: projection,
            reason: field(error, :message),
            request_id: request_id,
            tenant_id: tenant_id
          )

          {:error, error}
      end
    rescue
      error ->
        audit(:start_replay, :rejected,
          account_id: actor && actor.account_id,
          reason: Exception.message(error),
          request_id: request_id,
          tenant_id: tenant_id
        )

        {:error, Errors.from_exception(error)}
    end
  end

  @spec replay_status(String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def replay_status(job_id, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    actor = Keyword.get(opts, :actor)

    with {:ok, run} <- scoped_run(job_id, tenant_id),
         :ok <- authorize(actor, permission_for_mode(field(run, :mode))) do
      {:ok, run}
    end
  end

  @spec cancel_replay(String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def cancel_replay(job_id, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    actor = Keyword.get(opts, :actor)
    request_id = Keyword.get(opts, :request_id)
    projector = Api.projector_module()

    try do
      with {:ok, run} <- scoped_run(job_id, tenant_id),
           permission <- permission_for_mode(field(run, :mode)),
           :ok <- authorize(actor, permission) do
        result =
          try do
            case projector.cancel_replay(job_id) do
              :ok -> replay_status(job_id, tenant_id: tenant_id, actor: actor)
              {:error, error} -> {:error, normalize_error(error)}
            end
          rescue
            error -> {:error, Errors.from_exception(error)}
          end

        case result do
          {:ok, cancelled_run} ->
            audit(:cancel_replay, :accepted,
              account_id: actor && actor.account_id,
              job_id: job_id,
              mode: field(run, :mode),
              permission: permission,
              projection: field(run, :projection_name),
              request_id: request_id,
              tenant_id: tenant_id
            )

            {:ok, cancelled_run}

          {:error, error} ->
            audit(:cancel_replay, :rejected,
              account_id: actor && actor.account_id,
              job_id: job_id,
              mode: field(run, :mode),
              permission: permission,
              projection: field(run, :projection_name),
              reason: field(error, :message),
              request_id: request_id,
              tenant_id: tenant_id
            )

            {:error, error}
        end
      else
        {:error, error} ->
          audit(:cancel_replay, :rejected,
            account_id: actor && actor.account_id,
            job_id: job_id,
            reason: field(error, :message),
            request_id: request_id,
            tenant_id: tenant_id
          )

          {:error, error}
      end
    rescue
      error ->
        audit(:cancel_replay, :rejected,
          account_id: actor && actor.account_id,
          job_id: job_id,
          reason: Exception.message(error),
          request_id: request_id,
          tenant_id: tenant_id
        )

        {:error, Errors.from_exception(error)}
    end
  end

  defp normalize_projection(nil), do: raise(ArgumentError, "projection is required")
  defp normalize_projection("all"), do: :all
  defp normalize_projection(:all), do: :all
  defp normalize_projection(value), do: to_string(value)

  defp normalize_mode("catch_up"), do: "catch_up"
  defp normalize_mode("rebuild"), do: "rebuild"
  defp normalize_mode(_value), do: raise(ArgumentError, "mode must be catch_up or rebuild")

  defp replay_opts(attrs, tenant_id, actor, request_id, reason) do
    [tenant_id: tenant_id]
    |> maybe_put(:until_log_seq, value(attrs, :until_log_seq))
    |> maybe_put(:since_log_seq, value(attrs, :since_log_seq))
    |> maybe_put(:metadata, replay_metadata(attrs, actor, request_id, reason))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp replay_metadata(attrs, actor, request_id, reason) do
    attrs
    |> value(:metadata, %{})
    |> normalize_metadata!()
    |> Map.put_new("reason", reason)
    |> maybe_put_map("request_id", request_id)
    |> maybe_put_map("requested_by_account_id", actor && actor.account_id)
    |> maybe_put_map("requested_by_roles", actor && actor.roles)
  end

  defp normalize_metadata!(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata!(_metadata), do: raise(ArgumentError, "metadata must be an object")

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put_new(map, key, value)

  defp required_reason(attrs) do
    if Map.get(Api.admin_controls(), :require_reason, true) do
      attrs
      |> value(:reason, metadata_reason(attrs))
      |> normalize_reason!()
    else
      nil
    end
  end

  defp metadata_reason(attrs) do
    attrs
    |> value(:metadata, %{})
    |> case do
      metadata when is_map(metadata) -> value(metadata, :reason)
      _ -> nil
    end
  end

  defp normalize_reason!(nil),
    do: raise(ArgumentError, "reason is required for replay and rebuild admin actions")

  defp normalize_reason!(reason) when is_binary(reason) do
    case String.trim(reason) do
      "" -> raise(ArgumentError, "reason is required for replay and rebuild admin actions")
      normalized -> normalized
    end
  end

  defp normalize_reason!(reason), do: reason |> to_string() |> normalize_reason!()

  defp ensure_mode_enabled("catch_up"), do: :ok

  defp ensure_mode_enabled("rebuild") do
    if Map.get(Api.admin_controls(), :allow_rebuild, false) do
      :ok
    else
      {:error, Errors.forbidden("Projection rebuilds are disabled in this deployment")}
    end
  end

  defp authorize(%ServiceAccount{} = actor, permission) do
    if ServiceAccount.allows?(actor, permission) do
      :ok
    else
      {:error, Errors.forbidden("Service account lacks #{permission} permission")}
    end
  end

  defp authorize(nil, _permission) do
    {:error, Errors.forbidden("Service account context is required for admin actions")}
  end

  defp permission_for_mode("catch_up"), do: "projection_replay"
  defp permission_for_mode("rebuild"), do: "projection_rebuild"

  defp permission_for_mode(mode),
    do: raise(ArgumentError, "unsupported replay mode: #{inspect(mode)}")

  defp scoped_run(job_id, tenant_id) do
    projector = Api.projector_module()

    try do
      case projector.replay_status(job_id) do
        nil ->
          {:error, not_found(job_id)}

        run ->
          if field(run, :tenant_id) == tenant_id do
            {:ok, run}
          else
            {:error, not_found(job_id)}
          end
      end
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  defp not_found(job_id) do
    Errors.from_exception(Error.new(:not_found, "Replay job not found: #{job_id}"))
  end

  defp normalize_error(%HttpError{} = error), do: error
  defp normalize_error(error), do: Errors.from_exception(error)

  defp audit(action, outcome, opts) do
    Audit.admin_action(action, outcome, opts)
  rescue
    _error -> :ok
  end

  defp field(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp value(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end
end
