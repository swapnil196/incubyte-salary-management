# ADR 003 — Money is integer minor units with a snapshotted FX rate

**Status:** Accepted · **Date:** 2 October 2026

## Context

Salaries are money, in several currencies, and the dashboard has to total them into one currency.
Two things go wrong here routinely: floating point, and exchange rates that move.

`0.1 + 0.2 != 0.3` in IEEE 754. Summing 10,000 float salaries accumulates visible error, and a
payroll total that is wrong by a few cents is a total nobody trusts.

Separately, if conversion happens at read time against a live rate, the same report gives a
different answer every time it runs. That breaks reproducibility for the user and determinism for
the tests.

## Decision

Amounts are `BIGINT` minor units (cents) with an ISO 4217 currency code alongside. No floats and no
`DECIMAL` arithmetic in application code; a `Money` value object owns all arithmetic and refuses to
add two different currencies.

Each salary record stores `base_amount_cents`, `fx_rate` and `fx_rate_date`, computed once when the
record is written. Reports aggregate `base_amount_cents` and never convert at read time.

## Consequences

**What this buys us**

- Exact arithmetic. `SUM(base_amount_cents)` is correct at any row count.
- A report re-run in six months returns the same number it returned today.
- Tests are deterministic with no network call and no rate fixture drift.
- Adding two different currencies raises instead of silently producing nonsense.

**What it costs**

- Historic rows keep the rate from the day they were written. That is correct for "what did this
  cost us at the time", and wrong for "what would this cost at today's rate". The second question
  is out of scope; answering it later means a rate table join, not a schema change.
- Every write needs a rate available for that currency and date, so the rates table must be seeded
  before salary records.

## Alternatives considered

**`DECIMAL(12,2)` columns.** Exact, and a reasonable choice. Rejected because arithmetic then
scatters across the codebase in whatever precision each call site happens to use, and because
minor units make the "never a float" rule mechanically checkable.

**Converting at read time against a live rate API.** Non-reproducible reports, flaky tests, and a
network dependency on the dashboard's critical path.
