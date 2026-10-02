# How AI tools were used

The brief asks for AI to be used intentionally, so this records how, including where its output was
rejected.

**Tool:** Claude Opus 5 via Claude Code, with a `CLAUDE.md` holding the project's standing rules so
conventions did not have to be restated each time.

## Approach

The sequence was deliberate: requirements first, then architecture decisions, then schema, then
domain logic test-first, then API, then UI. The requirements document was written and reviewed
before any code existed, so scope was fixed before implementation could drift into it.

AI was used heavily for the parts that are well-understood and tedious — scaffolding, migration
boilerplate, React component structure, test fixtures, the seed generator — and used as a drafting
partner, not an authority, for the parts that carry the design: the data model, the effective-dating
transitions, and the statistics.

## Where AI output was rejected or corrected

Recorded as it happens, because the rejections say more than the acceptances.

| # | What was suggested | Why it was rejected |
|---|---|---|
| 1 | A requirements document with sections on the problem, personas, build principles, quality bar and definition of done | The brief asked for goal, scope, exclusions and reasoning. Everything else was padding against a one-page limit, and was cut. |

## Prompts that shaped the work

Kept in `docs/prompts/` where a prompt did real design work rather than just generating boilerplate.
