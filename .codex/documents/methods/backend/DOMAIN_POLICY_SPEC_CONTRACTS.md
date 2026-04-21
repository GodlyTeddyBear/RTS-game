# Domain Policy + Spec Contracts

Defines strict contracts for Domain policies and specifications.

Canonical architecture references:
- [../../architecture/backend/POLICIES_AND_SPECS.md](../../architecture/backend/POLICIES_AND_SPECS.md)
- [../../architecture/backend/CQRS.md](../../architecture/backend/CQRS.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)

---

## Policy Contract

- Policies own candidate construction from Infrastructure reads.
- `Policy:Check(...)` must return `Result.Result<TResolvedState>`.
- Success payload must include resolved state needed by caller execution steps.
- Policy methods are read/validate boundaries only.

---

## Spec Contract

- Specs are declared as named constants (`Spec.new(...)`) at module scope.
- Composed exports are named (for example `CanPlace = Spec.All({...})`).
- Spec failures must use context `Errors.lua` constants for error messages.
- Specs evaluate candidates only; they do not fetch state.

---

## Restore-Path Contract

- Restore commands keep policy checks when those checks resolve required runtime state.
- Restore commands may skip non-applicable side effects (for example redundant persist/sync), but not required policy resolution steps.

---

## Prohibitions

- Policies must not mutate sync state, save persistence data, or spawn side effects.
- Policies must not re-encode command orchestration responsibilities.
- Specs must not fetch infrastructure state.
- Specs must not use inline literal error strings when context errors constants exist.

---

## Failure Signals

- Policy returns only boolean pass/fail and forces command to re-fetch resolved state.
- Policy writes state (`Set*`, `Save*`, `Create*`, `Update*`) during validation.
- Spec is built inline inside policy method bodies rather than as module constants.
- Restore path skips policy and manually reconstructs resolved runtime objects.

---

## Checklist

- [ ] `Policy:Check(...)` returns `Result.Result<TResolvedState>`.
- [ ] Policy builds typed candidate from Infrastructure reads.
- [ ] Policy has no mutation side effects.
- [ ] Specs are named module-level constants with named composed exports.
- [ ] Spec failure messages come from `Errors.lua`.
- [ ] Restore command keeps policy resolution when required state is returned by policy.
