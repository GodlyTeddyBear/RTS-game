# Errors Contracts

Defines strict authoring rules for `Errors.lua` modules under `ServerScriptService/Contexts/[ContextName]/`.

Canonical architecture references:
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)

---

## Errors Module Contract

Every context that has Application or Domain modules must have exactly one `Errors.lua` at its context root.

The module must:

1. Define all error string constants as fields of a single table.
2. Return the table frozen with `table.freeze`.
3. Never expose methods, non-string values, or cross-module dependencies.

---

## Naming Rules

- Error keys are SCREAMING_SNAKE_CASE (e.g. `WAVE_ALREADY_ACTIVE`, `INVALID_PLAYER`).
- Error string values begin with the owning context prefix:
  - Application/Domain errors: `"[ContextName]Context: "`
  - Persistence errors: `"[ContextName]Persistence: "`
- The prefix must match the context directory name exactly.

---

## Usage Contract

- Callers pass error constants to `Result.Err(Errors.SOME_ERROR, ...)` — never an inline string.
- Error constants are the only allowed value for the type field of `Result.Err`.
- Do not catch and re-wrap error strings — propagate `Result` chains instead.

---

## Moonwave Documentation

Every error constant must carry a doc comment block with:

```lua
--[=[
    @prop KEY_NAME string
    @within Errors
    One sentence describing when this error is returned.
]=]
```

---

## Prohibitions

- Do not define errors for cases that cannot happen — every constant must have at least one caller.
- Do not define two constants with identical string values for logically distinct failures.
- Do not return the table unfrozen — always `return table.freeze(Errors)`.
- Do not import or require other modules inside `Errors.lua`.
- Do not use numeric, boolean, or table values — all constants must be strings.

---

## Failure Signals

- An error string value does not start with the expected `"[ContextName]Context: "` or `"[ContextName]Persistence: "` prefix.
- A caller passes a raw string to `Result.Err` instead of an `Errors.*` constant.
- `Errors.lua` is absent from a context that has Application or Domain modules.
- A constant is defined but never referenced by any caller in the context.
- The returned table is not frozen.
- A constant is missing its `@prop` Moonwave doc comment.

---

## Checklist

- [ ] One `Errors.lua` exists at the context root.
- [ ] All keys are SCREAMING_SNAKE_CASE.
- [ ] All string values carry the correct `"[ContextName]Context: "` or `"[ContextName]Persistence: "` prefix.
- [ ] Table is returned via `return table.freeze(Errors)`.
- [ ] Every constant has a Moonwave `@prop` doc comment with `@within Errors`.
- [ ] No methods, non-string fields, or module-level `require` calls present.
- [ ] Every constant is referenced by at least one caller via `Result.Err`.
