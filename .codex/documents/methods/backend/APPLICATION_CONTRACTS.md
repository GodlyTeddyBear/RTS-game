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

Command lifecycle requirements:
- Use `Init(registry, name)` for same-context dependencies that are available during `KnitInit`.
- Use `Start(registry, name)` for `EntityContext`, other external contexts, or any dependency that is only valid after context startup.
- `Execute(...)` must assume required dependencies are already resolved; do not perform lazy registry recovery inside `Execute(...)`.


---
## Query Contract

`Execute(...)` flow must follow this sequence:

1. Guard input inline.
2. Read from Infrastructure read APIs.
3. Return `Result.Ok(...)` data payload.

Query `Execute(...)` must return `Result.Result<T>`.

Queries are read-only and do not depend on Domain modules.

Query lifecycle requirements:
- Use `Init(registry, name)` for same-context dependencies.
- Use `Start(registry, name)` for external contexts or startup-ordered dependencies.
- Read helpers and query collaborators must not rely on post-bootstrap `Configure(...)` calls from the owning context.


---
## Prohibitions

### Commands
- Do not encode large inline business-rule trees directly in command methods.
- Do not bypass policies/specs for eligibility decisions.
- Do not mutate atom state outside Infrastructure sync/persistence services.
- Do not resolve required context dependencies lazily during `Execute(...)`.
- Do not use ad hoc `Configure(...)` methods to patch registry-managed dependencies after module creation.

### Queries
- Do not require/import `[ContextName]Domain/*`.
- Do not inject Domain services in `Init(...)`.
- Do not call Infrastructure mutation methods from queries.
- Do not use context-side setter wiring for registry-managed read dependencies.


---
## Failure Signals

- Command performs mutation before eligibility policy checks.
- Command contains duplicated business-rule branching that should live in specs/policies.
- Command or query caches `registry` only to recover dependencies later instead of using `Start(...)`.
- Command or query requires a manual `Configure(...)` call from its context to become valid.
- Query imports domain modules or calls domain services.
- Query calls write methods (for example `Set*`, `Update*`, `Create*`, `Save*`) on infrastructure services.
- `Execute(...)` returns plain values instead of `Result.Result<T>`.


---
## Checklist

- [ ] Command `Execute(...)` returns `Result.Result<T>`.
- [ ] Command flow is `Guard -> Policy/Domain -> Infra mutate -> Return`.
- [ ] Command business eligibility is delegated to Policy/Specs.
- [ ] Command dependencies follow `Init(...)` / `Start(...)` lifecycle rules and require no post-bootstrap setter wiring.
- [ ] Query `Execute(...)` returns `Result.Result<T>`.
- [ ] Query reads Infrastructure only and performs no mutation.
- [ ] Query/read dependencies follow `Init(...)` / `Start(...)` lifecycle rules and require no post-bootstrap setter wiring.
- [ ] Query has no Domain imports/injections.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

