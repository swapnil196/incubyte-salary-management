# ADR 004 — SQLite now, with a documented Postgres path

**Status:** Accepted · **Date:** 2 October 2026

## Context

The brief suggests SQLite. The workload is one HR Manager, 10,000 employees and roughly 30,000
salary records: small, read-heavy, with a single writer.

SQLite has one feature gap that matters here. It has no `percentile_cont`, and the dashboard is
built on medians and quartiles.

## Decision

SQLite, with all database access behind ActiveRecord and the analytics queries isolated in service
objects. Percentiles are computed by projecting a single ordered integer column and indexing into
it, rather than by a database function.

## Consequences

**What this buys us**

- Zero setup for a reviewer. Clone, `bin/setup`, run.
- Tests run against an in-memory database, so the suite stays fast and isolated.

**What it costs and when it breaks**

- SQLite serialises writes. Correct for one user; the moment this becomes multi-user with
  concurrent pay changes, writes queue. That is the trigger to move, not row count.
- Percentile computation pulls one `BIGINT` column for the filtered set. At 10,000 rows that is
  roughly 80 KB and microseconds. It stays reasonable to about 10^5 rows; past that, Postgres
  `percentile_cont` within a single aggregate query is the answer.
- No native `DECIMAL`. Already handled by ADR 003.

Moving to Postgres means a `database.yml` change and a migration run. No application code depends
on SQLite specifics, and that is deliberate.
