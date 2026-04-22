# Context Registry Contracts

Defines strict rules for the dependency registry setup flow inside every `[Context]Context.lua` Knit service.

Canonical architecture references:
- [../../architecture/backend/DDD.md](../../architecture/backend/DDD.md)
- [../../architecture/backend/CQRS.md](../../architecture/backend/CQRS.md)

---

## Core Rules

- `Registry.new("Server")` is called exactly once, at the top of `KnitInit` — never in `KnitStart`, never lazily.
- All module registrations happen before `registry:InitAll()`.
- `registry:InitAll()` is called exactly once, after all registrations are complete.
- All `registry:Get(...)` calls happen after `registry:InitAll()`.
- The registry reference is not stored on `self` — it is a local variable scoped to `KnitInit`.

---

## Registration Order

Modules must be registered in this strict order: **Infrastructure → Domain → Application**.

Dependencies only flow downward:

- **Infrastructure** depends on nothing registered above it in this context.
- **Domain** may depend on Infrastructure.
- **Application** may depend on Infrastructure and Domain.

Registering a module before its dependency is a runtime error; the order is the contract.

Raw values (e.g. a JECS world object, a Blink server module) that are not modules with an `Init` method may be registered without a category string. These must appear before the modules that depend on them.

---

## Cross-Context Dependencies

- `Knit.GetService(...)` calls belong in `KnitStart`, never in `KnitInit`.
- Cross-context service references are stored on `self` during `KnitStart` and passed into command or handler calls at the call site.
- Do not inject a cross-context service into the registry — the registry owns only this context's internal stack.

---

## Post-Init Caching

After `registry:InitAll()`, the context caches only the modules it needs for its public API:

```lua
self._someCommand = registry:Get("SomeCommand")
self._someQuery  = registry:Get("SomeQuery")
```

- Use `self._*` (underscore prefix) for all cached references.
- Do not cache every registered module — only those called from public methods or event handlers.
- Connections, signals, and cross-context references are initialized to `nil` in `KnitInit` and assigned in `KnitStart`.

---

## Connections and Subscriptions

- All `GameEvents.Bus:On(...)` and `Signal:Connect(...)` calls belong in `KnitStart`.
- Store every connection on `self` so `Destroy` can disconnect them.
- `KnitInit` must not subscribe to any event or signal.

---

## Prohibitions

- Do not call `registry:InitAll()` more than once.
- Do not call `registry:Get(...)` before `registry:InitAll()`.
- Do not store the registry on `self` or return it from any method.
- Do not register Application modules before Domain or Infrastructure modules.
- Do not call `Knit.GetService(...)` inside `KnitInit`.
- Do not perform game-state reads or mutations in `KnitInit`.

---

## Failure Signals

- A command or query `Init` fails with a "dependency not found" error — registration order is wrong.
- `KnitStart` calls `registry:Register(...)` or `registry:InitAll()`.
- A cross-context service reference is resolved inside `KnitInit`.
- The registry is accessible outside of `KnitInit` via `self._registry` or a closure.
- An event subscription fires before `KnitStart` completes because it was wired in `KnitInit`.

---

## Checklist

- [ ] `Registry.new("Server")` called once at the top of `KnitInit`.
- [ ] All registrations complete before `registry:InitAll()`.
- [ ] Registration order is Infrastructure → Domain → Application.
- [ ] `registry:InitAll()` called exactly once, before any `registry:Get(...)`.
- [ ] Registry reference is a local variable — not stored on `self`.
- [ ] `Knit.GetService(...)` calls are in `KnitStart`, not `KnitInit`.
- [ ] Connections and subscriptions are in `KnitStart` and stored on `self`.
- [ ] `Destroy` disconnects every stored connection.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

