# ADR 005 — No authentication in v1, but the deployment is not public

**Status:** Accepted · **Date:** 2 October 2026

## Context

The requirements document deliberately excludes login, accounts and permissions, on the grounds
that the brief describes a single trusted HR Manager and that auth is well-understood plumbing.

That reasoning holds for the application design. It does not hold for the deployed instance, which
will sit on a public URL carrying 10,000 realistic salary records.

## Decision

No user model, no sessions, no roles in the application. The deployed instance is protected by HTTP
Basic authentication, enabled only when `BASIC_AUTH_PASSWORD` is set in the environment, so local
development and the test suite are unaffected.

## Consequences

- The scope exclusion stands. There is still no concept of a user, a role or a permission anywhere
  in the domain, and nothing to unpick when real authentication arrives.
- The deployed demo is not an open salary database on the internet.
- The guard is a single `before_action` in `ApplicationController`, around six lines. It is not
  pretending to be the access control that was scoped out, and it should not be mistaken for it.

## Alternatives considered

**Deploy with no protection at all.** Internally consistent with the requirements document, and the
wrong call. Publishing a dataset that looks like real compensation data, unprotected, is a bad
instinct to demonstrate even when the data is synthetic.

**Build real authentication anyway.** Contradicts a documented scope decision for no reason, and
spends build time on the least interesting part of the problem.
