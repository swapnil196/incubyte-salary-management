# Salary Management

Employee salary management for an HR Manager: 10,000 employees, multiple countries and currencies.

Built as a single Rails 8.1 application serving a React 19 SPA, backed by SQLite.

## Documentation

| Document | What it covers |
|---|---|
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Goal, scope and what is deliberately left out |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System shape, data model, request flow |
| [docs/adr](docs/adr/README.md) | Decision records with the reasoning behind each |
| [docs/ENGINEERING_NOTES.md](docs/ENGINEERING_NOTES.md) | Per-commit performance, security and scalability analysis |
| [docs/AI_USAGE.md](docs/AI_USAGE.md) | How AI tools were used, including where output was rejected |

## Requirements

- Ruby 3.4.9 (see `.ruby-version`)
- Node 22.18.0 (see `.nvmrc`)

## Setup

```sh
bin/setup
```

Installs Ruby and JavaScript dependencies, prepares the database, and starts the application on
<http://localhost:3000>.

To seed 10,000 employees as part of setup:

```sh
bin/setup --seed
```

To set up without starting the server:

```sh
bin/setup --skip-server
```

## Running

```sh
bin/dev
```

Runs the Rails server and the Vite dev server together.

## Tests

```sh
bundle exec rspec     # Ruby: models, services, requests
npm test              # Frontend: components
npm run typecheck     # TypeScript
bin/rubocop           # Ruby style
bin/brakeman          # Static security analysis
bin/bundler-audit     # Known vulnerabilities in gems
```

All of the above run in CI on every push and pull request.
