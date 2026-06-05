# BaseApplication Contracts

Method contracts for using `ServerStorage.Utilities.BaseApplication` and derived `BaseCommand` / `BaseQuery` helpers.

Canonical architecture references:
- [../../architecture/backend/CQRS.md](../../architecture/backend/CQRS.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)
- [APPLICATION_CONTRACTS.md](APPLICATION_CONTRACTS.md)
- [EVENTS_CONTRACTS.md](EVENTS_CONTRACTS.md)

---

## Core Rules

- Use `BaseApplication.new(contextName, operationName)` to stamp a stable context/operation diagnostic label.
- `contextName` and `operationName` must be non-empty strings that match the owning command/query intent.
- Resolve infrastructure dependencies through `_RequireDependency(...)` or `_RequireDependencies(...)` when the dependency comes from registry lookups.
- Use `_GetGameEvent(contextName, eventName)` for event name resolution before emitting events.
- Keep `BaseApplication` and derived helpers technical: dependency resolution, event-name resolution, and shared guard assertions only.

---

## Constructor Contract

- Constructor intent is identity and diagnostics, not behavior ownership.
- `contextName` identifies the bounded context for assertions and labels.
- `operationName` identifies the command/query operation for assertions and labels.
- Derived constructors (`BaseCommand.new`, `BaseQuery.new`) must call `BaseApplication.new(...)` and only adjust metatable/class identity.

---

## Dependency Resolution Contract

- `_RequireDependency(registry, fieldName, registryName)` resolves exactly one dependency and stores it on `self[fieldName]`.
- `_RequireDependencies(registry, dependencyMap)` resolves each entry through `_RequireDependency(...)`.
- Dependency maps are field-to-registry-name mappings and must stay declarative.
- Dependency resolution in these helpers must not trigger business actions, writes, or side effects.
- Commands and queries must resolve same-context registry modules in `Init(...)`.
- Commands and queries must resolve cross-context or startup-ordered dependencies in `Start(...)`.
- Do not store a registry just to recover missing dependencies later at execution time.
- Do not patch command/query dependencies through ad hoc `Configure(...)` or setter-style methods after bootstrap.

---

## Event Resolution Contract

- `_GetGameEvent(contextName, eventName)` resolves event names from the canonical `GameEvents` registry.
- Derived command helpers should emit events using resolved names, not literal transport/event identifiers.
- Event-name resolution is lookup-only; ownership of event flow remains with command/query/application behavior.

---

## Prohibitions

- Do not add domain eligibility or policy/spec branching to `BaseApplication`, `BaseCommand`, or `BaseQuery`.
- Do not hardcode direct game event string literals in callers when resolver usage is required.
- Do not bypass registry resolution by writing ad-hoc dependency assignment logic in each command/query.
- Do not resolve cross-context dependencies in `Init(...)` when they are only guaranteed after service startup.
- Do not add lazy fallback dependency recovery inside `Execute(...)` for registry-managed modules.
- Do not mutate persistence, ECS, or runtime state from base helper methods.

---

## Failure Signals

- A base helper method contains business-rule branching specific to one context.
- Commands/queries emit hardcoded event identifiers instead of using `_GetGameEvent(...)`.
- Dependency fields are assigned manually from mixed sources without registry contract checks.
- A command/query uses `Configure(...)`, caches `registry`, or calls `registry:Get(...)` later to recover a missing dependency.
- A dependency that should be in `Start(...)` is instead resolved during `Execute(...)`.
- Base helper changes require feature-specific conditionals to stay working.

---

## Checklist

- [ ] Constructors use non-empty `contextName` and `operationName`.
- [ ] Derived constructors call `BaseApplication.new(...)`.
- [ ] Registry dependencies are resolved through `_RequireDependency(...)` or `_RequireDependencies(...)`.
- [ ] Same-context dependencies are resolved in `Init(...)`; cross-context or startup-ordered dependencies are resolved in `Start(...)`.
- [ ] Event names are resolved through `_GetGameEvent(...)` before emission.
- [ ] Base helpers contain only technical shared behavior (no domain-rule ownership).
