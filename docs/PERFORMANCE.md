# Performance

Measured on the seeded dataset: **10,000 employees, 32,634 salary records, 9,220 active**.

Reproduce with:

```sh
bin/rails benchmark
```

## A measurement error, and the correction

The first round of numbers in this project were wrong, and the mistake is worth recording because
it reversed an engineering decision.

Measurements were taken through `bin/rails runner`, which **enables the ActiveRecord query cache**.
A benchmark that runs one identical query twenty times in a loop then measures the cache, not the
database. The directory page appeared to take 5.8 ms; it actually took 15.4 ms. A deep page appeared
to take 4.0 ms; it actually took 48.4 ms.

Two conclusions were drawn from those figures and both were wrong:

1. *"Page 300 costs the same as page 1, so offset pagination is a non-issue here."* It does not.
   Uncached, depth cost 3× — 15.4 ms at page 1 against 48.4 ms at page 300.
2. *"A name-sort index saves 0.04 ms, so it is not worth adding."* Uncached, the same index saves
   **12.9 ms on the most common request in the application**.

A real HTTP request starts with an empty query cache and issues each distinct query once, so the
cache never helps a single page load. Benchmarks now disable it explicitly, and
`lib/tasks/benchmark.rake` carries a comment saying why so it cannot be quietly re-enabled.

The commit that introduced the directory endpoint (`422c764`) reports the cached figures. It is
left as written rather than rewritten, because the history is meant to show how the work actually
went.

## Current timings

Query cache disabled, logging disabled, mean of 20 runs, serialisation included where a page would
do it.

| Operation | Time |
|---|---|
| Directory, default page (25, active, by name) | **4.8 ms** |
| Directory, sorted by salary | 16.1 ms |
| Directory, sorted by compa-ratio | 17.4 ms |
| Directory, filtered by country and department | 5.8 ms |
| Directory, search term | 12.4 ms |
| Directory, deep page (page 300) | 16.2 ms |
| Directory, maximum page size (100 rows) | 10.0 ms |
| Insights dashboard (whole payload) | **117.7 ms** |
| CSV export, all 10,000 employees | 1,377 ms |

Target for interactive pages was under 300 ms. Everything meets it. The export does not, and is
discussed below.

## The one index that was added after measuring

```ruby
add_index :employees, %i[last_name first_name],
          where: "terminated_on IS NULL",
          name: "idx_employees_active_by_name"
```

Name is the directory's default sort, so it is the most requested ordering in the application.
Without the index, SQLite sorts all 9,220 active employees into a temporary B-tree on every page
view. With it, the scan walks the index in order and stops after the page.

| | Before | After |
|---|---|---|
| Page 1 | 15.4 ms | **2.5 ms** |
| Page 300 | 48.4 ms | **17.3 ms** |
| Sorted by salary (unaffected) | 14.1 ms | 15.1 ms |

Partial on `terminated_on IS NULL`, because the directory defaults to active employees and
indexing leavers would enlarge it for no benefit.

Sorting by salary or compa-ratio still sorts in a temp B-tree and cannot be indexed away: those
columns live on joined tables, so no index on `employees` can provide the order. 16 ms is
acceptable, and the alternative — a denormalised current-salary column on `employees` — is a second
source of truth, which ADR 002 rejected for good reasons.

## Query plans

Every join is index-backed. From `bin/rails benchmark:plans`:

```
Directory page
   SCAN employees USING INDEX idx_employees_active_by_name
   SEARCH departments USING INTEGER PRIMARY KEY (rowid=?)
   SEARCH job_levels USING INTEGER PRIMARY KEY (rowid=?)
   SEARCH salary_records USING INDEX idx_salary_records_current (employee_id=?) LEFT-JOIN
   SEARCH pay_bands USING INDEX idx_pay_bands_level_country (job_level_id=? AND country_code=?)

Directory filtered by country and department
   SEARCH employees USING INDEX idx_employees_directory_filters (country_code=? AND department_id=?)

Salary history for one employee
   SEARCH salary_records USING INDEX idx_salary_records_history (employee_id=?)
```

`idx_salary_records_current`, the partial unique index that enforces one-current-salary-per-employee,
is also the index that resolves the current-salary join. The invariant and the hot path are served
by the same structure.

## Query counts

| Endpoint | Queries |
|---|---|
| Directory page | 2 (one count, one fetch) |
| Employee detail | 4 (employee, department/level, history, band) |
| Insights dashboard | 3 |

The directory issues the same two queries whether it renders 1 row or 100: everything the
serializer needs is selected as aliased columns in the fetch. A spec asserts the count, so an N+1
reintroduced later fails the build instead of becoming 10,000 queries in production.

## The export is the slow one

1,377 ms for 10,000 rows, producing 1.6 MB. It is the only operation above the 300 ms target, and
it is stated here rather than omitted.

A download is a different contract from a page: someone who clicks Export expects a pause. Rows are
fetched in slices of 1,000 so memory stays bounded as the organisation grows, but the response is
still assembled in full before being sent. Streaming it with `ActionController::Live` is the next
step if exports reach a few tens of thousands of rows. Not done now, because at this size it would
be complexity with nothing to show for it.

## Optimisations deliberately not made

**No caching layer.** Nothing is above target except the export, and the export is a download. A
cache added now would be unmeasured, and would need invalidating on every pay change.

**No keyset pagination.** Offset depth does cost something — 2.5 ms at page 1 against 17.3 ms at
page 300 — but 17 ms is comfortable, and keyset pagination gives up the ability to jump to an
arbitrary page, which is exactly what HR does with a paged directory. The trigger for revisiting is
the directory growing by roughly an order of magnitude.

**No denormalised current-salary column on `employees`.** It would remove the join behind the
salary and compa-ratio sorts. Rejected because it is a second source of truth requiring
reconciliation, and the sorts it would fix are already at 16 ms.

## Where this breaks

| Limit | Trigger | Response |
|---|---|---|
| SQLite serialises writes | A second concurrent user making pay changes | Move to Postgres; `database.yml` change, no application code |
| Percentiles computed in Ruby | Roughly 10^5 active employees | Postgres `percentile_cont` inside the aggregate query |
| Export assembled in memory | Tens of thousands of rows | Stream with `ActionController::Live` |
| Offset pagination | Directory an order of magnitude larger | Keyset pagination, losing arbitrary page jumps |
