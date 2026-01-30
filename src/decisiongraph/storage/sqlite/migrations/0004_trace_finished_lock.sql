-- Migration: Prevent inserts after TraceFinished
-- Version: 0004
-- Description: Enforce TraceFinished locking atomically

CREATE TRIGGER dg_block_events_after_finish
BEFORE INSERT ON dg_event_log
WHEN NEW.event_type != 'TraceFinished'
  AND EXISTS (
      SELECT 1 FROM dg_event_log
      WHERE trace_id = NEW.trace_id AND event_type = 'TraceFinished'
  )
BEGIN
    SELECT RAISE(ABORT, 'trace_finished');
END;
