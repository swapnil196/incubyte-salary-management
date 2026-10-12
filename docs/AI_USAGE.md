# How AI tools were used

The brief asks for AI to be used intentionally. This records how: what it was given, what it was
not allowed to decide, and — most usefully — the places its output was wrong and what caught them.

**Tool:** Claude Opus 5 via Claude Code, with a `CLAUDE.md` holding the project's standing rules so
conventions did not have to be restated on every change.

## Approach

The sequence was deliberate: requirements, then architecture decisions, then schema, then domain
logic test-first, then API, then UI, then measurement. The requirements document was written and
reviewed before any code existed, so scope was fixed before implementation could quietly expand
into it.

**Where it was simply fast.** Migrations and schema boilerplate, React component structure and
Mantine wiring, factories and test scaffolding, serializers, the seed generator's weighted picks
and log-normal draw, and first drafts of documentation. This is the bulk of the typing in the
repository and none of it needed much supervision beyond review.

**Where it was a drafting partner rather than an authority.** The data model, the effective-dating
transitions, the statistics and the suppression rules. Here the pattern was: propose, argue,
reject, re-propose. The ADRs exist because those arguments were worth keeping.

**Where it was overruled or stopped.** Covered below.

The discipline that mattered most was **refusing to accept a passing test as proof**. Several
entries in the table are cases where the suite was green and something was still wrong.

## What AI was not allowed to decide

- **Scope.** Fixed in the requirements document before any code, and the exclusions were argued
  one at a time rather than generated as a list. Two rounds were spent cutting sections it added
  unasked.
- **The data model.** Effective-dated salary records, integer minor units, snapshotted FX rates and
  the partial unique index were settled and recorded as ADRs first; code was written to them.
- **What to test.** Coverage reached 99% as a consequence of testing the dangerous paths — money
  arithmetic, date transitions, suppression thresholds, malformed input — not as a target.
- **Whether a number was good.** Every performance claim here is reproducible with
  `bin/rails benchmark`. That is the only reason the error below was ever found.
- **When to stop.** Three attempts at a cosmetic index fix were abandoned deliberately rather than
  pursued to a fourth.

## Where AI output was wrong, or was rejected

Twelve entries across 22 commits. These are the corrections worth recording, not the total — the
routine ones, a wrong method name or a matcher that needed changing, are not here.

| # | What happened | Outcome |
|---|---|---|
| 1 | The first requirements document had sections on the problem, personas, build principles, a quality bar and a definition of done | The brief asked for goal, scope, exclusions and reasoning. Everything else was padding against a one-page limit. Cut to three sections over two rounds. |
| 2 | Test database configured as SQLite `:memory:` for speed | Each connection to `:memory:` gets its own empty database, so the schema loaded on one connection and examples ran on another. Capping the pool did not reliably fix it. Switched to a file; the speed difference is not measurable at this size. |
| 3 | A redundant single-column index on `salary_records.employee_id`, duplicating the leading column of a composite | `index: false` is not honoured for `t.references` on this adapter, and an explicit `remove_index` did not take either. **A workaround exists** — declare the column as `t.bigint` and add the foreign key separately — and was deliberately not taken: the cost is one surplus index on a table written once during seeding, which did not justify reworking the migration. Documented rather than hidden. |
| 4 | **Benchmarks measured through `bin/rails runner`** | `runner` enables the ActiveRecord query cache, so a loop of identical queries measured the cache. The directory page was reported at 5.8 ms; it was actually 15.4 ms. See below — this reversed two decisions. |
| 5 | "Offset pagination is a non-issue, page 300 costs the same as page 1" | False, and derived from #4. Uncached, depth cost 3×. |
| 6 | "A name-sort index saves 0.04 ms, not worth adding" | False, and derived from #4. Uncached the same index saves 12.9 ms on the most common request in the application. The index was added. |
| 7 | A spec intended to test the backdating rule | It was actually tripping the hire-date rule, so the rule under test was unreachable in that setup. Green for the wrong reason until the error *message* was asserted rather than just the failure. |
| 8 | Salary change endpoint returned **500** for an unparseable date | A plain user error producing a server error, because the service compared `nil` to a `Date`. Found by writing the malformed-input spec rather than only the happy path. Now a readable 422. |
| 9 | A frontend test expected `formatMoney(100_000, "USD")` to be `"$1,000"` | The code was right and the test was wrong: `en-GB` renders `US$`, which is what a multi-country HR team wants. Test corrected, not the code. |
| 10 | Ruby 3.1.2 assumed from the machine default | End-of-life since March 2025, and `json 3.x` will not build against it. Escalated as a decision rather than silently switched; moved to 3.4.9, which also meant Rails 8.1 rather than 7.2. |
| 11 | `require "csv"` in the export | Ruby 3.4 removed `csv` from the default gems. Caught by the suite rather than in production. |
| 12 | `index: false` on `t.references`, and `resource :reference` routing to `ReferenceController` | Both wrong in ways only the tests showed: the index is created anyway, and a singular resource expects a pluralised controller. |

### The measurement error is the one worth reading

Entries 4–6 are a single mistake with a long tail. A benchmark harness that looked reasonable was
measuring the wrong thing, the numbers were plausible, and two engineering decisions were made on
top of them — including a decision *not* to add an index, justified by a measurement that said it
was worthless.

Nothing about reviewing the code would have caught it. It surfaced only because the same queries
were later measured a second way, through a Rake task, and the two numbers disagreed by 40×. The
discrepancy was chased rather than averaged away.

The fix is in `lib/tasks/benchmark.rake`, which now disables both the logger and the query cache
with comments saying why, so neither can be quietly switched back on. The full account is in
[PERFORMANCE.md](PERFORMANCE.md), and the commit carrying the wrong figures was left as written
rather than rewritten.

## A caveat about this document

The table was reconstructed at the end rather than logged as the work went. That means these are
the corrections that were *memorable*, not necessarily the ones that were *representative*. A
standing instruction to log each correction as it happened would have produced a truer record.
