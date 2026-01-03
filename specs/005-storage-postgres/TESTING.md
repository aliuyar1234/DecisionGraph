# PostgreSQL Backend Testing Guide

## Prerequisites

The PostgreSQL backend tests require:

1. **psycopg library** (Python 3.0+)
2. **Running PostgreSQL instance** (12+)
3. **Test database** with appropriate permissions

## Installation

### Install PostgreSQL Support

```bash
pip install decisiongraph[postgres]
```

Or for development:

```bash
pip install -e ".[postgres,dev]"
```

## Setting Up PostgreSQL for Testing

### Option 1: Docker (Recommended)

Create a Docker Compose file for test database:

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: dg_test
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: testpass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Start the database:

```bash
docker-compose -f docker-compose.test.yml up -d
```

### Option 2: Local PostgreSQL

1. Install PostgreSQL 12 or later
2. Create test database:

```sql
CREATE DATABASE dg_test;
CREATE USER dg_user WITH PASSWORD 'testpass';
GRANT ALL PRIVILEGES ON DATABASE dg_test TO dg_user;
```

## Running Tests

### Set Connection String

```bash
export PG_CONNINFO="host=localhost dbname=dg_test user=postgres password=testpass"
```

Or on Windows:

```cmd
set PG_CONNINFO=host=localhost dbname=dg_test user=postgres password=testpass
```

### Run PostgreSQL Tests

```bash
# Run all PostgreSQL backend tests
pytest tests/integration/test_postgres_backend.py -v

# Run parity tests
pytest tests/integration/test_parity.py -v

# Run optional import tests
pytest tests/unit/test_optional_postgres.py -v

# Run all postgres-related tests
pytest -k postgres -v
```

### Skip PostgreSQL Tests

If `PG_CONNINFO` is not set, the tests will automatically skip:

```bash
# This will skip postgres tests
unset PG_CONNINFO
pytest tests/integration/test_postgres_backend.py -v
```

## Test Coverage

### Integration Tests (test_postgres_backend.py)

- **TC-P4-001**: `test_pg_migrate_fresh_db` - Migrations apply cleanly
- **TC-P4-002**: `test_pg_append_persists` - Events persist correctly
- **TC-P4-003**: `test_pg_idempotency_unique` - Idempotency constraint works
- **TC-P4-004**: `test_pg_trace_seq_unique` - trace_seq uniqueness enforced
- **TC-P4-007**: `test_pg_list_events_order` - Events ordered by log_seq
- **TC-P4-008**: `test_pg_finish_locks` - TraceFinished prevents appends
- **TC-P4-009**: `test_pg_error_mapping_storage` - Errors map correctly

### Parity Tests (test_parity.py)

- **TC-P4-006**: `test_pg_digest_matches_sqlite` - Digest parity verified
- `test_parity_get_trace_events` - Query parity
- `test_parity_list_events` - List parity
- `test_parity_idempotency_behavior` - Idempotency parity
- `test_parity_projector_digest` - Projector digest parity
- `test_parity_trace_finished_lock` - Lock behavior parity

### Unit Tests (test_optional_postgres.py)

- **TC-P4-010**: `test_pg_optional_extra_import` - Optional import works
- `test_import_without_psycopg` - Graceful handling without psycopg
- `test_import_with_psycopg` - Successful import with psycopg
- `test_core_functionality_without_postgres` - Core works without Postgres

## Performance Testing

### 10K Event Append Test

```python
import time
from decisiongraph.storage.postgres import PostgresEventStore
from decisiongraph.testing import create_test_envelope
from decisiongraph.ids import generate_trace_id
from decisiongraph.domain.events import EVENT_TYPE_TRACE_STARTED, EVENT_TYPE_ENTITY_OBSERVED

store = PostgresEventStore("host=localhost dbname=dg_test user=postgres password=testpass")

start = time.time()

# Append 10K events
for i in range(10000):
    trace_id = generate_trace_id()
    env = create_test_envelope(
        trace_id=trace_id,
        trace_seq=0,
        event_type=EVENT_TYPE_TRACE_STARTED,
        payload={"workflow": "perf", "title": f"Event {i}"},
    )
    store.append_event(env)

elapsed = time.time() - start
print(f"10K appends: {elapsed:.2f}s")  # Should be < 10s

store.close()
```

## Troubleshooting

### Connection Refused

If you get "connection refused":

1. Check PostgreSQL is running: `docker ps` or `systemctl status postgresql`
2. Verify port 5432 is accessible: `telnet localhost 5432`
3. Check firewall settings

### Authentication Failed

If you get "authentication failed":

1. Verify username/password in `PG_CONNINFO`
2. Check `pg_hba.conf` for authentication method
3. Ensure user has database permissions

### Schema Not Found

If you get "schema not found":

1. Migrations should auto-apply on first connection
2. Verify database exists: `psql -l`
3. Check user has CREATE permissions

### Tests Skipped

If tests are skipped:

1. Install psycopg: `pip install psycopg`
2. Set PG_CONNINFO environment variable
3. Verify PostgreSQL is running

## CI/CD Setup

### GitHub Actions Example

```yaml
name: Test PostgreSQL Backend

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: dg_test
          POSTGRES_PASSWORD: testpass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          pip install -e ".[postgres,dev]"

      - name: Run PostgreSQL tests
        env:
          PG_CONNINFO: "host=localhost dbname=dg_test user=postgres password=testpass"
        run: |
          pytest tests/integration/test_postgres_backend.py -v
          pytest tests/integration/test_parity.py -v
```

## Cleanup

After testing:

```bash
# Stop Docker container
docker-compose -f docker-compose.test.yml down -v

# Or drop test database
psql -c "DROP DATABASE dg_test;"
```
