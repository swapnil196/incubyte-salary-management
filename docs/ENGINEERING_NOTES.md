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

### Employee and salary schema: invariants in the database

**The partial unique index is the centrepiece.**

```sql
CREATE UNIQUE INDEX idx_salary_records_current
  ON salary_records (employee_id) WHERE effective_to IS NULL;
```

"An employee has at most one salary in force" is now a property of the data, not a promise made by
the service layer. Two concurrent pay-change requests cannot both succeed: one gets a constraint
violation. A spec asserts this by bypassing validations entirely and expecting
`ActiveRecord::RecordNotUnique`, so the guarantee is tested where it actually lives.

It is also the index behind the hottest query in the application — current pay for every employee —
which it answers without touching the table.

**Check constraints, not just validations.** Three of them: a termination cannot precede its hire, a
salary period cannot end before it starts, and an amount must be positive. Each is paired with a
spec that bypasses validations with `update_column` and expects
`ActiveRecord::StatementInvalid`. Validations are a user-experience feature; constraints are the
guarantee. A background job, a console session or a future bulk import does not run validations.

**Equal effective dates are legal.** `effective_to >= effective_from`, not `>`. A record whose period
starts and ends on the same day covers zero days, which is exactly right for a salary corrected the
same day it was entered: it never applied. Forbidding it would make same-day corrections impossible.

**effective_to is exclusive.** The successor applies from the day the predecessor ends, so there is
no one-day gap and no overlap. Tested directly at the boundary.

**Index choices on employees.** The directory filter index is
`(country_code, department_id, job_level_id)`, in that order, because country is the most selective
of the three in a multi-country organisation and leading with it eliminates the most rows earliest.
The "active employees" index is partial on `terminated_on IS NULL`, so it indexes only the rows that
match rather than the whole table.

**N+1 prevention is asserted, not hoped for.** `with_directory_associations` eager-loads department,
job level and current salary. A spec walks all three associations across several employees inside
`expect { }.not_to make_database_queries`, so an N+1 reintroduced later fails the build rather than
turning into 10,000 queries in production.

**One redundancy accepted deliberately.** `t.references :employee` creates a single-column index on
`employee_id` that duplicates the leading column of `idx_salary_records_history`. On this adapter
`index: false` does not suppress it, and an explicit `remove_index` did not take either. It was left
in place. The cost is one extra index to maintain on a table written once during seeding and rarely
afterwards; the cost of continuing to chase it was more time than the write throughput is worth.
Recorded rather than quietly dropped, because an unexplained redundant index looks like carelessness
and this one is a decision.

### RecordSalaryChange

The only way a salary changes. Closes the record in force and opens a new one inside one
transaction.

**Expected failures return a Result; unexpected ones raise.** A date before the hire, a missing
exchange rate or an unrecognised reason are things a user can legitimately do, so they come back as
`Result.failure(message)` for the controller to render. A unique-index violation from a concurrent
write is not a user error, so it is left to raise and surface as a 500 rather than being flattened
into a friendly message that hides a real problem.

**Atomicity is tested by forcing the second half to fail.** A spec stubs `SalaryRecord.create!` to
raise, then asserts the employee still has an open salary record. Without the transaction the close
would commit and the insert would not, leaving someone with no current pay — silent, and invisible
until a payroll total came out short. This is the failure mode the transaction exists to prevent, so
it is tested directly rather than assumed from the presence of a `transaction` block.

**Future-dating is rejected, deliberately.** Allowing a scheduled raise would mean the open record
(`effective_to IS NULL`) is not actually in force yet, contradicting the invariant that the partial
unique index encodes and that every analytics query relies on. Supporting it properly means defining
"current" as `in_force_on(Date.current)` and giving up the index-only lookup. That is a real feature
with a real cost, and it is out of scope. Rejected with a clear message rather than silently
mishandled.

**Backdating before the record in force is rejected.** Editing a period that has already been closed
means splitting history, which needs the correction workflow that was scoped out. Changes dated
within the open period are fine, including same-day.

**The FX rate and its publication date are both stored.** `FxRate.conversion_on` returns the rate
together with the date it was published, so a conversion can be explained afterwards: "100,000 USD
at 0.92, published 1 December" rather than a number nobody can reproduce. Storing only the rate
would make the figure correct but unauditable.

**Ordering of the validation checks matters.** Amount and reason are checked before any date logic,
and the hire-date check runs before the in-force check. Writing the spec surfaced that a test aimed
at the in-force rule was actually tripping the hire-date rule, which means the rule was unreachable
in that setup. Worth noting because it is the kind of thing a passing test suite hides: the
assertion was green for the wrong reason until the message was asserted, not just the failure.

**Performance.** One indexed lookup for the record in force, one `UPDATE` by primary key, one
`INSERT`. The close uses `update_column` to skip validations and callbacks, because the record being
closed was already valid and re-validating it would be two extra queries for no benefit.

### Pay bands and compa-ratio

**Bands are stored in the base currency, not in local currency.** A band answers "is this person
paid correctly for their level here", and the comparison is against `base_amount_cents`, which is
already in the base currency. Storing bands the same way makes the comparison apples-to-apples by
construction, with no conversion at read time and nothing to get wrong. Rendering a band in local
currency is a display concern.

The alternative — local-currency bands with converted copies alongside — would mirror the salary
record's shape but add six columns and a second rate snapshot to a table that exists purely as a
reference. Not worth it for a value HR sets once per level per country.

**Compa-ratio is salary over midpoint**, the standard measure, rounded to four places. That is more
precision than anyone displays, and enough that sorting by it does not wobble between equal-looking
values.

**Band edges are inclusive.** Paid exactly at the minimum is inside the band, not below it. Tested
at both boundaries, because off-by-one here means an employee appears on an exceptions report that
HR then has to explain to them.

**Currency mismatch raises instead of comparing.** `position_for` takes a `Money` and leaves the
currency check to that class. Handing it a USD salary against a EUR band raises rather than
producing a plausible and meaningless ratio. This is the payoff for making `Money` strict earlier:
the rule is enforced once and every caller inherits it.

**`Employee#pay_band` is a single-record lookup and says so.** Calling it per row in a list issues
one query per employee. The comment on it points bulk callers at a SQL join on
`(job_level_id, country_code)`, which is how the outliers query in the insights service will do it.
Documented at the definition rather than discovered in a profiler.

**Degenerate bands are allowed.** `min == mid == max` is valid: a fixed-rate role has no range. The
check constraint enforces ordering, not distinctness.

---

## Phase 2 — Data

### Seed: 10,000 employees in 9.3 seconds

**Measured on this machine:** 10,000 employees and 32,634 salary records in **9.34s**.

**Batched inserts, not ActiveRecord creates.** 42,634 rows created one at a time through
`create!` means 42,634 round trips plus validation and callback overhead per row, which runs into
minutes. `insert_all!` in slices of 1,000 brings it to seconds. Primary keys are assigned explicitly
during generation, so salary records can reference their employee without a lookup pass.

The trade-off is that `insert_all!` skips validations. Accepted here because the database carries
the real constraints — the partial unique index, three check constraints, the foreign keys — so
malformed data still cannot land. Reference data is small enough to create normally, so validations
do run over it.

**Determinism via one injected `Random`.** Every draw, including Faker's, comes from a generator
built from a single seed. The same seed produces byte-identical data. A demo that looks different
on every run is impossible to discuss, and the seed spec asserts this directly by generating twice
and comparing.

**Floats are used freely in generation, and that is not a contradiction.** The log-normal draw and
the weighted picks are floats, because they produce a *distribution*. Every value is rounded to an
integer number of cents at the moment it becomes money. Nothing stored or summed is ever a float.

**Why log-normal rather than uniform.** Pay within a level clusters near the midpoint with a longer
tail upwards. A uniform spread would put every median suspiciously close to every band midpoint and
make the dashboard look synthetic. Measured result, by level:

| Level | n | Median (EUR) |
|---|---|---|
| Intern | 273 | 22,865 |
| Mid | 2,454 | 50,188 |
| Senior | 2,177 | 66,718 |
| Director | 766 | 147,727 |

**Outliers are planted on purpose.** 5.7% below band minimum, 5.0% above maximum — partly planted,
partly the natural tail of the distribution. An exceptions report cannot be demonstrated, or
tested, against data containing no exceptions.

**So is the gender pay gap.** The generator applies a deliberate factor to produce a small gap,
because the pay equity view exists to surface one and a feature that always renders "no gap" is
untested and unconvincing. The factors are an arbitrary fiction chosen to make the feature
demonstrable. They are not a claim about any real organisation, and the seed code says so at the
constant.

**Terminated employees have no open salary record.** Their final record is closed at the termination
date. This is semantically right — their pay ended — and it means every payroll total naturally
excludes leavers without needing a special case, because the aggregate joins on
`effective_to IS NULL`. Verified: 9,220 active employees, 9,220 open records, zero terminated
employees with an open record.

**`faker` moved out of the development group.** The seed has to be runnable against the deployed
instance, and a gem scoped to development would make that fail at the point it mattered.

**The seed spec runs the real generator at 60 rows.** It asserts determinism, that every active
employee has exactly one salary in force, that no leaver has an open record, that history is
contiguous with no gaps or overlaps, and that `base_amount_cents` is consistent with the local
amount and the stored rate. A generator that quietly produced two open salaries would break the
dashboard in a way no unit test elsewhere would catch.

---

## Phase 3 — API

### Employees directory endpoint

**Measured on the seeded database** (10,000 employees, 32,634 salary records), mean of 20 runs
including serialisation:

| Request | Time |
|---|---|
| Default page (25, active, by name) | 5.8 ms |
| Sorted by salary, descending | 4.7 ms |
| Sorted by compa-ratio, descending | 4.5 ms |
| Filtered by country and department | 5.4 ms |
| Search term | 4.2 ms |
| Deep page (page 300) | 4.0 ms |
| Maximum page size (100 rows) | 11.6 ms |

Target was under 300 ms. The deep-page figure is the interesting one: it confirms the earlier claim
that offset pagination is a non-issue at this scale, so keyset pagination stays a documented upgrade
path rather than code nobody needed.

#### Security

**Sort columns are whitelisted, not sanitised.** A sort column cannot be passed as a bind parameter,
so an interpolated one is a direct injection route. `SORTABLE` maps public names to SQL fragments
that are literals in the source file; an unrecognised value falls back to the default. A spec sends
`sort=employees.id; DROP TABLE employees--` and asserts both that the response is a normal 200 and
that the table still has its rows.

**Page size is capped at 100.** Without a ceiling, `?per_page=999999` is a single request that
returns every salary in the organisation. Nonsense values fall back to the default rather than
erroring.

**LIKE wildcards in the search term are escaped** with `sanitize_sql_like`. Unescaped, a search for
`%` matches every row, and the user silently receives the entire directory instead of no results.
Tested.

**`config.filter_parameters` covers amounts, currency, email and names**, so compensation data
cannot reach a log file or an exception report.

**Unrecognised filter values are ignored rather than rejected.** An unknown `status` falls back to
`active`. The alternative, a 422, turns a stale bookmark into an error page for no benefit.

#### Performance

**The count query runs against a bare `Employee` scope.** Every filter and the search term reference
columns on `employees` alone, so the department, job level, salary and pay band joins contribute
nothing to the count. Correctness is identical either way — all the joins are one-to-at-most-one, so
there is no row multiplication — but this query runs on every page request, and leaving four joins
in it to produce a number they do not affect is waste.

**Two queries per page, regardless of page size.** One count, one fetch. Everything the serializer
needs is selected in that single fetch as aliased columns, so the serializer never triggers a lazy
load. A spec asserts `make_database_queries(count: 2)` while rendering 20 rows, so an N+1
reintroduced later fails the build.

**The pay band join is raw SQL** because the condition spans `job_level_id` and `country_code`,
which no Rails association can express. It contains no user input.

#### Design

Controllers parse parameters, call one object, render. `Employees::Query` exposes `filtered_scope`
without pagination specifically so the CSV export can reuse the identical filter set instead of
reimplementing it and drifting out of step.
