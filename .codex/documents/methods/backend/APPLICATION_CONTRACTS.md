# Application Contracts

Defines strict method contracts for `Application/Commands/*` and `Application/Queries/*`.

Canonical architecture references:
- [../../architecture/backend/CQRS.md](../../architecture/backend/CQRS.md)
- [../../architecture/backend/DDD.md](../../architecture/backend/DDD.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Command Contract

`Execute(...)` flow must follow this sequence:

1. Guard input (`Ensure(...)` and structural checks).
2. Resolve business eligibility through Policy/Domain.
3. Mutate runtime state through Infrastructure.
4. Return `Result.Ok(...)` confirmation payload.

Command `Execute(...)` must return `Result.Result<T>`.


---
## Query Contract

`Execute(...)` flow must follow this sequence:

1. Guard input inline.
2. Read from Infrastructure read APIs.
3. Return `Result.Ok(...)` data payload.

Query `Execute(...)` must return `Result.Result<T>`.

Queries are read-only and do not depend on Domain modules.


---
## Prohibitions

### Commands
- Do not encode large inline business-rule trees directly in command methods.
- Do not bypass policies/specs for eligibility decisions.
- Do not mutate atom state outside Infrastructure sync/persistence services.

### Queries
- Do not require/import `[ContextName]Domain/*`.
- Do not inject Domain services in `Init(...)`.
- Do not call Infrastructure mutation methods from queries.


---
## Failure Signals

- Command performs mutation before eligibility policy checks.
- Command contains duplicated business-rule branching that should live in specs/policies.
- Query imports domain modules or calls domain services.
- Query calls write methods (for example `Set*`, `Update*`, `Create*`, `Save*`) on infrastructure services.
- `Execute(...)` returns plain values instead of `Result.Result<T>`.


---
## Checklist

- [ ] Command `Execute(...)` returns `Result.Result<T>`.
- [ ] Command flow is `Guard -> Policy/Domain -> Infra mutate -> Return`.
- [ ] Command business eligibility is delegated to Policy/Specs.
- [ ] Query `Execute(...)` returns `Result.Result<T>`.
- [ ] Query reads Infrastructure only and performs no mutation.
- [ ] Query has no Domain imports/injections.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

