# Quickstart: PostgreSQL Storage Backend

## Installation

```bash
# Install with Postgres support
pip install decisiongraph[postgres]
```

## Setup PostgreSQL

```bash
# Using Docker
docker run -d \
  --name decisiongraph-postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=decisiongraph \
  -p 5432:5432 \
  postgres:15
```

## Basic Usage

```python
from decisiongraph.storage.postgres import PostgresEventStore

# Connect to Postgres
store = PostgresEventStore(
    "host=localhost dbname=decisiongraph user=postgres password=secret"
)

# Use exactly like SQLiteEventStore
stored = store.append_event(envelope)
events = store.get_trace_events(trace_id)
```

## Parity Verification

```python
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.storage.postgres import PostgresEventStore
from decisiongraph.projections import Projector

# Create both stores
sqlite_store = SQLiteEventStore(":memory:")
pg_store = PostgresEventStore("host=localhost dbname=test user=postgres")

# Insert same events
for envelope in events:
    sqlite_store.append_event(envelope)
    pg_store.append_event(envelope)

# Build projections
sqlite_proj = Projector(sqlite_store)
pg_proj = Projector(pg_store)
sqlite_proj.rebuild()
pg_proj.rebuild()

# Verify digest parity
assert sqlite_proj.compute_digest("context_graph") == \
       pg_proj.compute_digest("context_graph")
```

## Connection String Formats

```python
# Standard format
"host=localhost dbname=mydb user=myuser password=secret"

# URI format
"postgresql://user:password@localhost/dbname"

# With options
"host=localhost dbname=mydb user=myuser sslmode=require"
```

## Running Tests

```bash
# Start Postgres
docker-compose up -d postgres

# Run tests
pytest tests/integration/test_postgres_backend.py
pytest tests/integration/test_parity.py

# Stop Postgres
docker-compose down
```

## Next Steps

After this phase, proceed to `006-query-layer` for:
- Query API implementation
- Precedent search
- Staleness checks
