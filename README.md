# Salary Management

Employee salary management for an HR Manager: **10,000 employees, seven countries, five
currencies**.

A spreadsheet is already an adequate record of who earns what. What it cannot do is tell you who is
underpaid, what payroll costs, or what you paid someone eighteen months ago. That gap is what this
is for.

Rails 8.1 serving a React 19 SPA, backed by SQLite.

---

## Running it

Requires **Ruby 3.4.9** (`.ruby-version`) and **Node 22.18.0** (`.nvmrc`).

```sh
bin/setup --seed
```

Installs dependencies, prepares the database, seeds 10,000 employees, and starts on
<http://localhost:3000>. Takes about a minute, of which 9 seconds is the seed.

```sh
bin/setup --skip-server   # set up without starting
bin/dev                   # Rails + Vite together
```

## Checks

```sh
bundle exec rspec     # 248 examples — models, services, requests
npm test              # 47 tests — components and formatters
npm run typecheck     # TypeScript
bin/rubocop           # Ruby style
bin/brakeman          # static security analysis
bin/bundler-audit     # known gem vulnerabilities
bin/rails benchmark   # reproducible performance measurements
```

Line coverage is 99%, weighted towards money arithmetic, effective dating and malformed input
rather than spread evenly.

## What it does

**Manage salary data** — directory with search and filters across 10,000 records, employee profile
with full salary history, effective-dated pay changes carrying a reason, pay bands per level and
country, salaries held in local currency with a stored exchange rate.

**Answer questions about pay** — payroll cost and median, distributions by country, department and
level, who sits outside their pay band (filterable, and reachable in one click from the dashboard),
pay equity within level and country, CSV export of any filtered view.

## Three decisions that shape everything

**Salary is an effective-dated record, not a column.** A pay change closes one record and opens
another; nothing is ever overwritten. Point-in-time questions become ordinary SQL, and every change
carries a reason. ([ADR 002](docs/adr/002-effective-dated-salary-records.md))

**One current salary per employee is a database guarantee**, not a convention:

```sql
CREATE UNIQUE INDEX idx_salary_records_current
  ON salary_records (employee_id) WHERE effective_to IS NULL;
```

A concurrent double-submit gets a constraint violation rather than two live salaries. The same
index resolves the hottest query in the application.

**Money is integer minor units, and the FX rate is snapshotted at write time.** The `Money` value
object refuses `Float` by type, so `salary * 1.03` raises rather than accumulating binary error
across 10,000 rows. A report re-run next quarter returns the number it returned today.
([ADR 003](docs/adr/003-money-as-integer-minor-units.md))

## Performance

Measured on the seeded dataset, query cache disabled. Reproduce with `bin/rails benchmark`.

| Operation | Time |
|---|---|
| Directory, default page | 4.8 ms |
| Directory, deep page (300) | 16.2 ms |
| Insights dashboard | 117.7 ms |
| CSV export, 10,000 rows | 1,377 ms |
| Seed 10,000 employees | 9.3 s |

Full analysis, query plans, and the optimisations deliberately **not** made are in
[PERFORMANCE.md](docs/PERFORMANCE.md) — including a measurement error that reversed two decisions.

## Documentation

| Document | What it covers |
|---|---|
| [REQUIREMENTS.md](docs/REQUIREMENTS.md) | Goal, scope, and what is deliberately left out |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System shape, data model, request flow |
| [adr/](docs/adr/README.md) | Five decision records with reasoning |
| [ENGINEERING_NOTES.md](docs/ENGINEERING_NOTES.md) | Per-commit performance, security and scalability analysis |
| [PERFORMANCE.md](docs/PERFORMANCE.md) | Timings, query plans, limits, and a measurement error |
| [AI_USAGE.md](docs/AI_USAGE.md) | How AI was used, and the twelve places its output was wrong |

## Not built, on purpose

Login and permissions, payroll execution, bonuses and equity, approval workflows, bulk CSV import,
live FX feeds, UI translation. Each is argued individually in
[REQUIREMENTS.md §3](docs/REQUIREMENTS.md).

Login is the one to add first: it is the only exclusion that blocks real use. Everything else on
that list is a missing feature; that one is the reason this could not go in front of a real HR
team. The reasoning is in [ADR 005](docs/adr/005-no-auth-in-v1.md).

**Deployment is also deliberately out of scope.** This runs locally and is demonstrated on video.

Hosting it would have meant putting 10,000 realistic-looking salary records on a public URL, which
then needs access control — and access control is the thing explicitly excluded above. The honest
options were to build the auth that was scoped out, or to leave a compensation dataset readable by
anyone who found the link. Neither is a good trade for an exercise, so the application was built to
be run and read rather than hosted.

Nothing in the design depends on that choice. Persistence sits behind ActiveRecord with no
SQLite-specific code, so moving to Postgres is a `database.yml` change
([ADR 004](docs/adr/004-sqlite-with-a-postgres-path.md)), and the frontend is served by the same
application rather than a separate host ([ADR 001](docs/adr/001-single-rails-app-serving-react.md)).

## Status

Built, tested and documented, running locally. 255 Ruby examples and 47 frontend tests pass;
Rubocop, Brakeman and bundler-audit are clean.
