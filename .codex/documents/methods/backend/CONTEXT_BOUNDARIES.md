# Context Boundaries Contract

Defines strict method contracts for `[ContextName]Context.lua` boundaries.

Canonical architecture references:
- [../../architecture/backend/DDD.md](../../architecture/backend/DDD.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Method Categories

1. `Server public` - public server-to-server context methods.
2. `.Client delegate` - `.Client` methods that call `self.Server:Method(...)`.
3. `.Client direct Execute` - `.Client` methods that call an Application command/query `Execute(...)` directly.


---
## Contract

### 1) Server public
- Must return `Result.Result<T>`.
- Must own the `Catch(...)` boundary (except simple getter methods explicitly allowed to return `Ok(value)` directly).
- Must propagate failures by return value; do not convert failures to defaults in public API paths.

### 2) .Client delegate
- Must delegate directly to `self.Server:Method(...)`.
- Must not add another `Catch(...)` when delegating.
- Must not reshape the delegated `Result` unless explicitly marked as a terminal/private boundary.

### 3) .Client direct Execute
- May own a `Catch(...)` when directly calling `Execute(...)`.
- Must return `Result.Result<T>` compatible output so `WrapContext` can preserve rejection behavior.


---
## Prohibitions

- Do not implement business orchestration in `Context.lua`.
- Do not run policy/spec decision logic in `Context.lua`.
- Do not perform infrastructure persistence/sync mutations directly in `Context.lua`.
- Do not stack multi-hop `Catch(...)` wrappers across a delegate chain by default.
- Do not use `unwrapOr(default)` in public server-to-server context method return paths.


---
## Failure Signals

- A `.Client` delegate method wraps `self.Server:Method(...)` in `Catch(...)`.
- A server public method returns a plain value instead of `Result.Result<T>`.
- A context method contains validation trees, policy checks, or persistence write steps instead of delegating.
- A public method swallows failures with fallback defaults.


---
## Checklist

- [ ] Method is correctly classified (`Server public`, `.Client delegate`, `.Client direct Execute`).
- [ ] Exactly one `Catch` owner exists for the request path.
- [ ] Public server-to-server method returns `Result.Result<T>`.
- [ ] `Context.lua` method remains bridge-only (route/delegate only).
- [ ] No fallback swallowing (`unwrapOr`) in public return path.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

