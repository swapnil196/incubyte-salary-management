# Salary Management — working conventions

Employee salary management for an HR Manager. 10,000 employees, multiple countries and currencies.
Read [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) for scope and [docs/adr](docs/adr/README.md) for
why the design is shaped the way it is.

## Stack

Rails 8.1 (Ruby 3.4.9, pinned in `.ruby-version`) · React 18 + TypeScript via `vite_rails` · Mantine · SQLite · RSpec · Vitest

Node is pinned in `.nvmrc`. The default `node` on this machine is too old for Vite.

## Rules

**Money.** Never a float. Amounts are `BIGINT` minor units with an ISO 4217 currency code, and all
arithmetic goes through the `Money` value object. Adding two currencies must raise.

**Salary history.** Never update a salary record in place. A pay change closes the open record and
inserts a new one, inside one transaction. The partial unique index on `(employee_id) WHERE
effective_to IS NULL` is the guarantee — do not work around it.

**Where logic lives.** Domain logic goes in `app/services` as plain Ruby objects. Controllers parse
parameters, call one service, render. No business logic in controllers, and none in ActiveRecord
callbacks.

**SQL safety.** Sort and filter parameters are whitelisted against a fixed list. Never interpolate
a user-supplied value into a SQL fragment, including column names.

**Aggregates.** Computed by the database. If a method loads rows to count or sum them, it is wrong.

## Tests

Test-first for anything with logic: money, effective dating, statistics. Fast, deterministic,
offline — in-memory database, frozen clock, fixed random seed. No sleeps, no network, no reliance
on today's date.

Run: `bundle exec rspec` and `npm test`.

## Commits

Small and incremental, one logical change each. The commit body says what changed and why, and
notes any performance or security consideration. Record non-obvious decisions as an ADR in
`docs/adr/`, and per-commit analysis in `docs/ENGINEERING_NOTES.md`.
