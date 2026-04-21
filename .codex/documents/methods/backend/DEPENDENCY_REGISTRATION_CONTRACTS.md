# Dependency Registration Contracts

Method contracts for registry lifecycle and cross-context dependency wiring in backend contexts.

---

## Intent

Prevent startup-order defects by separating:

1. Context-owned module initialization.
2. Cross-context dependency registration.
3. Module start lifecycle.

This contract applies to server contexts that use `Registry`.

---

## Required Lifecycle Pattern

### `KnitInit` (owned modules only)

- Create a new registry.
- Register only modules/services owned by the current context.
- Call `registry:InitAll()` once owned modules are registered.
- Cache context-owned module references from the registry.

### `KnitStart` (cross-context registration + start)

- Resolve other Knit services with `Knit.GetService(...)`.
- Register those external dependencies in the same registry.
- Call `registry:StartOrdered({ "Domain", "Infrastructure", "Application" })` (or the minimal ordered subset used by the context).

---

## Prohibitions

- Do not call `Knit.GetService(...)` in `KnitInit` for dependencies that are not context-owned.
- Do not register cross-context dependencies in `KnitInit`.
- Do not call `registry:InitAll()` in `KnitStart`.
- Do not manually call `module:Init(...)` per-module when `InitAll` can perform the lifecycle pass.

---

## Module Contract For Cross-Context Dependencies

When a module needs dependencies registered during `KnitStart`:

- `Init` should resolve only context-owned registry dependencies.
- `Start` should resolve cross-context dependencies (`RunContext`, `WorldContext`, `EnemyContext`, etc.).

This ensures `InitAll` is safe in `KnitInit` before external contexts are registered.

---

## Failure Signals

- `Registry` errors in startup such as:
  - `[Registry] module not found: <CrossContextDependency>`
- Runtime nil-index errors caused by modules assuming dependencies were initialized in the wrong lifecycle phase.
- Re-initialization bugs caused by invoking `InitAll` after external modules/services were registered.

---

## Checklist

- `KnitInit` contains only context-owned `registry:Register(...)` calls.
- `KnitInit` calls `registry:InitAll()` exactly once.
- `KnitStart` performs all `Knit.GetService(...)` resolution.
- `KnitStart` registers cross-context dependencies before `StartOrdered(...)`.
- Modules that need cross-context services resolve them in `Start`, not `Init`.

