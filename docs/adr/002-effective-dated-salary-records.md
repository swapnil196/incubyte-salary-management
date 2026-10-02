# ADR 002 — Salary is an effective-dated record, not a column

**Status:** Accepted · **Date:** 2 October 2026

## Context

The obvious model is `employees.salary_cents`. It is also what the spreadsheet already does, and
it is the specific thing that makes the spreadsheet useless for the HR Manager's real questions.

With a single column, a raise destroys the previous value. You cannot answer "what did we pay this
person last year", "what did payroll cost in Q1", or "what was the average increase at the last
review cycle". Those are the questions this product exists to answer.

## Decision

`salary_records` is a separate table. Each row carries `effective_from`, a nullable `effective_to`,
an amount, a currency and a `change_reason`. Recording a pay change closes the open record by
setting its `effective_to`, then inserts a new open record. Nothing is ever updated in place.

The invariant "an employee has at most one open salary record" is enforced by the database:

```sql
CREATE UNIQUE INDEX idx_salary_records_current
  ON salary_records (employee_id) WHERE effective_to IS NULL;
```

## Consequences

**What this buys us**

- Full history with no extra audit table, and a reason attached to every change.
- Point-in-time queries become ordinary SQL: `WHERE effective_from <= :date AND (effective_to IS
  NULL OR effective_to > :date)`.
- The partial unique index makes a double-submit a constraint violation rather than two live
  salaries. The bug cannot reach the data, regardless of what the service layer does.
- Reading current pay for every employee is a single index-backed scan on `effective_to IS NULL`.

**What it costs**

- Every read of "current salary" is a join, not a column. Mitigated by the partial index.
- Backdating is now a real scenario with real edge cases, so it needs real tests. That is the
  correct cost to pay; the alternative is pretending the scenario does not exist.
- Roughly three rows per employee, so about 30,000 rows rather than 10,000. Irrelevant at this size.

## Alternatives considered

**Salary column plus a `salary_audit_log` table.** The log is write-only and nothing reads it, so it
drifts from the truth and nobody notices. Point-in-time questions have to replay the log.

**Denormalised `current_salary_cents` on `employees`, kept in sync.** A real option for performance
at much larger scale. Rejected now because two sources of truth need reconciliation, and at 10,000
rows the partial index is already fast. Noted as the first thing to try if the directory query ever
becomes a bottleneck.
