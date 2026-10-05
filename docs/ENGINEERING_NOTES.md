# Engineering notes

A running log of the performance, security and scalability reasoning behind each piece of code.
Entries are written in the same commit as the code they describe.

Format: what was built, what could go wrong, what was done about it.

---

## Phase 0 — Foundation

### Why these notes exist

Decisions that are obvious while writing code are invisible a week later, and invisible to a
reviewer reading a diff. Anything chosen for a reason — an index, a cap, an escape, a rejected
optimisation — is recorded here with the reasoning, including the optimisations deliberately
not made.

### Standing rules

**Security**

- No user input reaches SQL as a fragment. Sort columns and filter keys are whitelisted against a
  fixed allowlist; anything else is rejected, not sanitised.
- Pagination has a hard maximum. An uncapped `per_page` is a one-request dump of the whole salary
  table.
- `config.filter_parameters` covers salary amounts and email, so compensation data never reaches a
  log file or an error report.
- Any value written to CSV that begins with `=`, `+`, `-` or `@` is escaped. HR opens these files
  in Excel, where an unescaped formula is code execution on their machine.

**Performance**

- No endpoint loads a full table into memory. Aggregates are computed by the database.
- Associations used by a list view are eager-loaded. Bullet runs in development to catch N+1s.
- Any index added is justified by a specific query, and the justification goes in these notes.

**Scalability**

- Where a choice is correct now but wrong at larger scale, the note records the trigger for
  changing it, not just the limitation.

### Toolchain: Ruby 3.4.9 and Rails 8.1

The machine's default Ruby was 3.1.2, which reached end of life in March 2025 and could not build
several native gems against the current macOS SDK. Moved to Ruby 3.4.9, which also means Rails 8.1
rather than 7.2. ADR 001 is amended accordingly. There is nothing in the design that depends on the
Rails major version; the change is about not shipping on an unsupported runtime.

Node is pinned in `.nvmrc` to 22.18.0. The machine's default `node` is v12, which Vite refuses.

### Test database is file-backed, not in memory

First attempt pointed the test environment at SQLite `:memory:`, on the reasoning that it would be
faster and leave nothing on disk. It was abandoned.

Each connection to `:memory:` gets its **own** empty database. The schema loaded on the connection
that `rails_helper` used, and examples then ran on a different pooled connection against nothing.
Capping the pool to one connection did not reliably fix it, because the in-memory database only
survives as long as that specific connection object does, and Rails 8 manages connection leasing
itself.

Now `storage/test.sqlite3` with `maintain_test_schema!`. SQLite writes go to the page cache, so the
speed difference at this suite size is not measurable, and the setup stops fighting the framework.
Transactional fixtures still roll back every example, so nothing leaks between tests.

Worth recording as a cost that was correctly refused: the in-memory version was a micro-optimisation
with no measured benefit, and chasing it further would have bought nothing.

### SPA fallback does not capture API paths

The catch-all route that serves the React shell is constrained to exclude `/api`, `/vite` and `/up`.
Without that constraint, a mistyped API path returns 200 with an HTML body, and the frontend tries
to parse markup as JSON — a confusing failure a long way from its cause. A request spec asserts the
404 directly, so the constraint cannot be removed silently.

### Coverage measurement

SimpleCov runs with branch coverage enabled and separate groups for services and value objects,
which is where the logic worth covering will live. Coverage is a diagnostic, not a target; the
intent is to see untested branches in the domain layer, not to chase a percentage.

---

## Phase 1 — Domain core

### Reference schema: departments, job levels, FX rates

**Why job levels carry a `rank`.** The meaningful ordering of seniority is not alphabetical —
"Junior, Mid, Senior, Staff" sorts to "Junior, Mid, Senior, Staff" by luck, and "L9, L10" does not
sort correctly at all. An explicit integer rank, uniquely indexed, keeps the ordering unambiguous
and makes "the level above this one" a real query rather than a string comparison.

**FX rate lookup is most-recent-on-or-before, not exact match.** Rates are published irregularly.
Asking for "the USD rate on 3 March" normally means the rate published on 1 March and not yet
superseded. An exact-date lookup would raise on most dates. This also makes backdated salary
records convert at the rate that was actually in force at the time, which is the correct behaviour
for "what did this cost us then".

**Index design.** `idx_fx_rates_lookup` is `(currency, base_currency, rate_date)` unique. The two
leading columns match the equality predicates and the trailing date column serves both the range
scan and the `ORDER BY ... DESC LIMIT 1`, so the query is answered from the index without touching
the table. The same index doubles as the uniqueness constraint.

**Uniqueness is enforced twice, deliberately.** The ActiveRecord validation and the unique database
index are not redundant. The validation produces a readable error in the normal case; the index is
the actual guarantee, because the validation has a check-then-insert race that two concurrent
requests can slip through.

**`rate_on` raises rather than defaulting.** A missing rate could return 1.0, or nil, or the nearest
future rate. All three silently produce a wrong number in a payroll total. Raising
`FxRate::RateUnavailable` makes the gap visible at the point it occurs. Converting the base currency
to itself short-circuits to exactly 1 without a query.

**Scale.** The FX table holds one row per currency per publication date — hundreds of rows, read
constantly and written rarely. It is a candidate for in-process caching if it ever shows up in a
profile. It has not, so it is not cached.

### Money value object

**Floats are rejected by type, not converted.** `Money#*` and `Money.from_major` raise `ArgumentError`
when handed a `Float`. This is the point of the class. A rule in a style guide saying "don't use
floats for money" is advice; a constructor that refuses the type is enforcement. `salary * 1.03`
fails loudly at the call site instead of accumulating binary rounding error invisibly across 10,000
rows. `String`, `Integer`, `BigDecimal` and `Rational` are all accepted, so the rule costs the caller
nothing except writing `BigDecimal("1.03")`.

**Currency mismatch raises, including in comparison.** `<=>` asserts matching currencies before
comparing, so `eur < usd` raises rather than quietly comparing raw integers. Without that, sorting a
mixed-currency collection produces an order that looks sensible and means nothing. `==` returns
false across currencies rather than raising, because equality is a legitimate question to ask of two
arbitrary values; ordering is not.

**Rounding is half-up at the minor unit**, applied once at the boundary rather than at each step.
Payroll convention, and tested explicitly at the .5 boundary so a future refactor to banker's
rounding cannot pass silently.

**Instances are frozen** and `hash`/`eql?` are defined together, so `Money` is safe as a Hash key and
cannot be mutated through a shared reference.

**Deliberately not built:** division, and allocation (splitting an amount across n parts without
losing cents to rounding). Both are real money problems and neither is in scope here — nothing
divides a salary. Adding them speculatively would mean untested code paths in the most
correctness-sensitive class in the system.

**Performance.** `Money` is a thin wrapper over an Integer and never touches the database.
Aggregation deliberately does **not** go through it: totals are summed in SQL over
`base_amount_cents` and wrapped in a `Money` once, at the edge. Instantiating 10,000 objects to add
them up would be the obvious wrong turn here.
