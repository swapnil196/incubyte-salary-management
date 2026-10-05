# Architecture

One Rails 8.1 application serving a React SPA, backed by SQLite. Decisions behind this shape are
recorded in [docs/adr](adr/README.md).

## System shape

```mermaid
flowchart TB
    subgraph browser["Browser"]
        react["React 18 + TypeScript<br/>Mantine · TanStack Query"]
    end

    subgraph rails["Rails 8.1 application"]
        vite["vite_rails<br/>serves the bundle"]
        api["Api::V1 controllers<br/>JSON only"]
        services["Domain services<br/>plain Ruby objects"]
        models["ActiveRecord models<br/>persistence + invariants"]
    end

    db[("SQLite<br/>Postgres-ready")]

    react -->|"GET /api/v1/..."| api
    vite -.->|"initial page load"| react
    api --> services
    services --> models
    models --> db
```

The important line is `api --> services`. Controllers parse parameters, call one service, and
render. They hold no business logic. Services are plain Ruby objects with no Rails dependency
beyond the models they touch, which is what makes them fast and pleasant to test.

## Data model

```mermaid
erDiagram
    DEPARTMENTS ||--o{ EMPLOYEES : employs
    JOB_LEVELS  ||--o{ EMPLOYEES : grades
    JOB_LEVELS  ||--o{ PAY_BANDS : "defines band for"
    EMPLOYEES   ||--o{ SALARY_RECORDS : "has history of"

    EMPLOYEES {
        bigint  id PK
        string  employee_number UK
        string  country_code "ISO 3166-1 alpha-2"
        bigint  department_id FK
        bigint  job_level_id FK
        string  gender "nullable"
        date    hired_on
        date    terminated_on "nullable"
    }

    SALARY_RECORDS {
        bigint  id PK
        bigint  employee_id FK
        bigint  amount_cents "minor units"
        string  currency "ISO 4217"
        bigint  base_amount_cents "converted once, at write time"
        decimal fx_rate
        date    fx_rate_date
        date    effective_from
        date    effective_to "NULL means current"
        string  change_reason
    }

    PAY_BANDS {
        bigint  id PK
        bigint  job_level_id FK
        string  country_code
        bigint  min_cents
        bigint  mid_cents
        bigint  max_cents
    }

    FX_RATES {
        string  currency
        string  base_currency
        decimal rate
        date    rate_date
    }
```

### The invariant that matters

```sql
CREATE UNIQUE INDEX idx_salary_records_current
  ON salary_records (employee_id) WHERE effective_to IS NULL;
```

An employee has at most one open salary record, enforced by the database rather than by convention.
A concurrent double-submit raises a constraint violation instead of creating two live salaries.
The same index makes "current pay for everyone" a single cheap scan.

## Request flow — recording a pay change

```mermaid
sequenceDiagram
    participant UI as React
    participant C as Api::V1::SalaryRecordsController
    participant S as RecordSalaryChange
    participant DB as SQLite

    UI->>C: POST /api/v1/employees/:id/salary_records
    C->>C: strong params, whitelist, coerce
    C->>S: call(employee:, amount:, currency:, effective_from:, reason:)
    S->>DB: BEGIN
    S->>DB: lock employee row
    S->>S: validate — no overlap, rate available
    S->>DB: UPDATE open record SET effective_to = effective_from
    S->>DB: INSERT new open record with fx snapshot
    S->>DB: COMMIT
    S-->>C: Result.success(record)
    C-->>UI: 201 Created
```

Close-then-insert runs in one transaction. If the insert violates the partial unique index, the
close is rolled back with it, so the employee is never left with no current salary.

## Layout

```
app/
  controllers/api/v1/    JSON controllers, thin
  models/                persistence and invariants
  services/              domain logic, plain Ruby
    salaries/            RecordSalaryChange, SalaryHistory
    insights/            PayrollTotals, Distribution, Outliers, PayEquity
  values/                Money and other value objects
  javascript/            React app
db/
  seeds/                 deterministic 10,000-employee generator
spec/                    RSpec — unit heavy, request specs at the edges
docs/                    requirements, ADRs, engineering notes
```
