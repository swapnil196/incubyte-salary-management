# ADR 005 — No authentication in v1

**Status:** Accepted · **Date:** 2 October 2026 · **Amended:** 12 October 2026 (deployment dropped)

## Context

The brief describes a single user: the HR Manager at ACME, who is authorised to see every
employee's pay. There is no second role in the problem statement, nobody whose view must be
restricted, and no approval step that needs an actor.

## Decision

No user model, no sessions, no roles, no permissions. The application has no concept of "who is
asking", and nothing in the domain is shaped around one.

## Consequences

**What this buys us**

- Build time goes to the parts of the problem that are actually interesting. Authentication is
  well-understood plumbing; implementing it would demonstrate nothing that is not already
  demonstrated elsewhere in this codebase.
- No premature access-control model to unpick. Adding real authentication later means adding a
  layer, not rewriting one that was guessed at.

**What it costs**

- **This is the exclusion that blocks real use.** Everything else left out of scope is a missing
  feature; this one is the reason the software cannot be put in front of an actual HR team. It is
  the first thing to add.
- The API has no CSRF protection, which is currently correct — there are no sessions or cookies, so
  there is no ambient authority for a forged request to borrow. That stops being true the moment
  authentication is added, because the browser then attaches credentials automatically. Recorded
  here so it is not missed.

## Alternatives considered

**Build authentication anyway.** Contradicts a documented scope decision for no reason, and spends
build time on the least interesting part of the problem.

**Ship a token or a shared password as a token gesture.** An earlier revision of this ADR specified
HTTP Basic authentication for a deployed instance, so that a public URL carrying 10,000 realistic
salary records would not be readable by anyone who found it. That reasoning was sound while a
deployment was planned. Deployment is now deliberately out of scope (see the README), so the guard
protected nothing and was removed rather than left as code justified by a scenario that no longer
exists.
