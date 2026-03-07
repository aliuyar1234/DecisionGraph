defmodule DecisionGraph.Store.Repo.Migrations.CreateDgEventLog do
  use Ecto.Migration

  @event_types [
    "TraceStarted",
    "InputObserved",
    "EntityObserved",
    "PolicyEvaluated",
    "ExceptionRequested",
    "ApprovalRecorded",
    "WorkflowReviewRequested",
    "PrecedentCited",
    "ActionProposed",
    "ActionCommitted",
    "TraceFinished"
  ]

  def up do
    create table(:dg_event_log, primary_key: false) do
      add(:log_seq, :bigserial, primary_key: true)
      add(:tenant_id, :text, null: false, default: "default")
      add(:event_id, :text, null: false)
      add(:trace_id, :text, null: false)
      add(:trace_seq, :integer, null: false)
      add(:event_type, :text, null: false)
      add(:occurred_at, :text, null: false)
      add(:recorded_at, :text, null: false)
      add(:producer_id, :text, null: false)
      add(:source_system, :text, null: false)
      add(:source_subsystem, :text)
      add(:actor_type, :text, null: false)
      add(:actor_id, :text, null: false)
      add(:correlation_id, :text)
      add(:causation_event_id, :text)
      add(:idempotency_key, :text, null: false)
      add(:schema_version, :integer, null: false, default: 1)
      add(:payload_json, :text, null: false)
      add(:payload_hash, :text, null: false)
      add(:tags_json, :text, null: false, default: "[]")
    end

    create(unique_index(:dg_event_log, [:event_id], name: :dg_event_log_event_id_unique))

    create(
      unique_index(:dg_event_log, [:tenant_id, :trace_id, :trace_seq],
        name: :dg_event_log_trace_seq_unique
      )
    )

    create(
      unique_index(:dg_event_log, [:tenant_id, :producer_id, :idempotency_key],
        name: :dg_event_log_idempotency_unique
      )
    )

    create(
      index(:dg_event_log, [:tenant_id, :trace_id, :log_seq], name: :dg_event_log_trace_log_idx)
    )

    create(
      index(:dg_event_log, [:tenant_id, :event_type, :log_seq], name: :dg_event_log_type_log_idx)
    )

    create(
      index(:dg_event_log, [:tenant_id, :trace_id, :event_type],
        name: :dg_event_log_trace_type_idx
      )
    )

    execute("""
    ALTER TABLE dg_event_log
    ADD CONSTRAINT dg_event_log_trace_seq_non_negative
    CHECK (trace_seq >= 0)
    """)

    execute("""
    ALTER TABLE dg_event_log
    ADD CONSTRAINT dg_event_log_schema_version_positive
    CHECK (schema_version > 0)
    """)

    execute("""
    ALTER TABLE dg_event_log
    ADD CONSTRAINT dg_event_log_event_type_valid
    CHECK (event_type IN (#{Enum.map_join(@event_types, ", ", &"'#{&1}'")}))
    """)

    execute("""
    CREATE OR REPLACE FUNCTION dg_validate_event_log_insert()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
      expected_seq integer;
    BEGIN
      IF NEW.event_type = 'TraceStarted' AND NEW.trace_seq <> 0 THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'trace_started_requires_zero';
      END IF;

      IF NEW.event_type <> 'TraceStarted' AND NEW.trace_seq = 0 THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'first_event_must_be_trace_started';
      END IF;

      IF EXISTS (
        SELECT 1
        FROM dg_event_log
        WHERE tenant_id = NEW.tenant_id
          AND trace_id = NEW.trace_id
          AND event_type = 'TraceFinished'
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'trace_finished_lock';
      END IF;

      SELECT COALESCE(MAX(trace_seq) + 1, 0)
      INTO expected_seq
      FROM dg_event_log
      WHERE tenant_id = NEW.tenant_id
        AND trace_id = NEW.trace_id;

      IF NEW.trace_seq <> expected_seq THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = format('trace_seq_expected:%s', expected_seq);
      END IF;

      RETURN NEW;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER dg_event_log_validate_insert
    BEFORE INSERT ON dg_event_log
    FOR EACH ROW
    EXECUTE FUNCTION dg_validate_event_log_insert()
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS dg_event_log_validate_insert ON dg_event_log")
    execute("DROP FUNCTION IF EXISTS dg_validate_event_log_insert()")
    drop(table(:dg_event_log))
  end
end
