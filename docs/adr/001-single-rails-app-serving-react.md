# ADR 001 — One Rails app serves the React SPA

**Status:** Accepted · **Date:** 2 October 2026

## Context

The brief requires a Rails backend and a React frontend. That can be built two ways: as two
deployable units (a Rails API and a separately hosted React build), or as one Rails app that
serves a React bundle from the same origin.

A reviewer will clone this repository and try to run it. That weighs heavily here.

## Decision

One Rails 7.2 application. React with TypeScript is built by Vite through the `vite_rails` gem and
served by Rails. The API lives under an explicit `/api/v1` namespace and returns JSON only.

## Consequences

**What this buys us**

- `bin/setup && bin/dev` starts everything. No second terminal, no port juggling.
- Same origin, so no CORS configuration and no preflight requests.
- One deployment artifact, one set of environment variables, one place for logs.
- The API boundary is still explicit. Controllers under `Api::V1` never render HTML, so splitting
  the frontend out later means changing a base URL, not untangling the two.

**What it costs**

- The frontend cannot be deployed independently of the backend, or scaled separately. For a
  single-user internal tool neither matters.
- The deploy host needs Node at build time. Handled in the Dockerfile.

## Alternatives considered

**Split Rails API and a static React app on a CDN.** Correct for a public product with independent
release cycles. Here it buys nothing and costs CORS setup, a second deploy target, and a reviewer
experience that starts with "run these two things in two terminals."

**Rails with Hotwire and no React.** Rejected: the brief names React.
