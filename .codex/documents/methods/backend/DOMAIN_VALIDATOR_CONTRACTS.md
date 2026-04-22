# Domain Validator Contracts

Defines strict authoring rules for `[Name]Validator.lua` services inside `[Context]Domain/Services/`.

Canonical architecture references:
- [../../architecture/backend/DDD.md](../../architecture/backend/DDD.md)
- [../../architecture/backend/POLICIES_AND_SPECS.md](../../architecture/backend/POLICIES_AND_SPECS.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)

---

## Core Rules

- Validators are stateless, or seeded once at construction — they never mutate runtime state after `new()`.
- A validator owns exactly one domain concept (e.g. request shape, resource earn/spend). Do not bundle unrelated validation concerns in the same class.
- Validators live in `[Context]Domain/Services/` and are registered in the context registry under the `"Domain"` category.

---

## Return Contract

Every public validation method must return `Result.Result<T>`:

- Return `Ok(payload)` when the input is valid. The payload is the sanitized/typed form of the input.
- Return `Err(type, Errors.CONSTANT)` when the input fails a simple check.
- Return `Err(type, Errors.CONSTANT, data)` when structured context (e.g. current balance, requested cost) is useful for error surfaces downstream.

Use `Ensure(condition, type, Errors.CONSTANT)` for simple boolean guard checks — it throws and is caught by `Catch`. Use `Err(...)` directly when you need to attach data to the failure or when the check is conditional on prior state.

---

## Helper Methods

- Private helpers are prefixed with `_` (e.g. `_IsPositiveInteger`, `_IsKnownResourceType`).
- Private helpers return plain booleans — not `Result` types.
- Private helpers contain the reusable check logic; public methods compose them and return `Result`.

---

## Scope Boundaries

Validators validate **shape and eligibility** only:

- They may read constructor-seeded data (e.g. a config table frozen at `new()`).
- They must not read Infrastructure state — no atom reads, no runtime service calls, no ProfileStore access.
- They must not emit events or mutate any state.
- Balance-check validation (e.g. `ValidateSpend`) receives the current balance as a parameter — it does not query it internally.

---

## Prohibitions

- Do not read Infrastructure services or atoms from inside a validator.
- Do not emit `GameEvents` or fire signals from a validator.
- Do not bundle validation for unrelated domain concepts in the same class.
- Do not return plain values from validation methods — always return `Result.Result<T>`.
- Do not make private helpers return `Result` — they return booleans only.

---

## Failure Signals

- A validator method queries Infrastructure (calls a service, reads an atom) to obtain a value it should have received as a parameter.
- A private `_helper` method returns `Result.Ok(...)` or `Result.Err(...)` instead of a boolean.
- A single validator class contains methods for two distinct domain concepts (e.g. placement shape AND resource spend).
- A public method returns a plain value instead of `Result.Result<T>`.
- The validator is registered under `"Infrastructure"` or `"Application"` instead of `"Domain"`.

---

## Checklist

- [ ] Validator is stateless or seeded-at-construction only.
- [ ] All public methods return `Result.Result<T>`.
- [ ] `Ok(payload)` returns the sanitized input on success.
- [ ] `Err(type, Errors.CONSTANT)` or `Err(type, Errors.CONSTANT, data)` returned on failure.
- [ ] `Ensure(...)` used for simple boolean guards; `Err(...)` used when attaching failure context.
- [ ] Private helpers prefixed `_` and return plain booleans.
- [ ] No Infrastructure reads, atom access, or event emissions inside the validator.
- [ ] Registered under `"Domain"` category in the context registry.
- [ ] Owns exactly one domain validation concept.
