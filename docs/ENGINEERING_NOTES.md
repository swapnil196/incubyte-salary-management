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

### Test database held in memory

`config/database.yml` points the test environment at `:memory:` and `spec/rails_helper.rb` loads the
schema into that connection once at boot. The suite leaves nothing on disk and there is no state to
leak between runs.

**Cost:** the suite runs in one process. Parallel test workers would each need their own database,
so this choice would be revisited if suite runtime ever justified parallelism. At the current size
it does not.

### SPA fallback does not capture API paths

The catch-all route that serves the React shell is constrained to exclude `/api`, `/vite` and `/up`.
Without that constraint, a mistyped API path returns 200 with an HTML body, and the frontend tries
to parse markup as JSON — a confusing failure a long way from its cause. A request spec asserts the
404 directly, so the constraint cannot be removed silently.

### Coverage measurement

SimpleCov runs with branch coverage enabled and separate groups for services and value objects,
which is where the logic worth covering will live. Coverage is a diagnostic, not a target; the
intent is to see untested branches in the domain layer, not to chase a percentage.
