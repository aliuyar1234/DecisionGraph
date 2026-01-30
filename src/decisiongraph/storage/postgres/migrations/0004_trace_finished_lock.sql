-- Migration: Prevent inserts after TraceFinished
-- Version: 0004
-- Description: Enforce TraceFinished locking atomically

CREATE OR REPLACE FUNCTION dg_block_events_after_finish()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.event_type <> 'TraceFinished'
       AND EXISTS (
            SELECT 1 FROM dg_event_log
            WHERE trace_id = NEW.trace_id AND event_type = 'TraceFinished'
       ) THEN
        RAISE EXCEPTION 'trace_finished';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER dg_block_events_after_finish
BEFORE INSERT ON dg_event_log
FOR EACH ROW
EXECUTE FUNCTION dg_block_events_after_finish();
