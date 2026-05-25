# Option vs Nil

Prefer `Option` over raw `nil` when a value may be absent and that absence needs to survive debugging, tracing, or call-site intent.

Canonical references:
- [Option.lua](../../../src/ReplicatedStorage/Utilities/Option.lua)
- [LUAU_TYPES.md](LUAU_TYPES.md)
- [ERROR_HANDLING.md](../architecture/backend/ERROR_HANDLING.md)

---

## Core Rules

- Use `Option.Wrap(value)` at boundaries where a value may or may not exist.
- Use `Option.Some(value)` only when the value is definitely present.
- Return `Option.None` instead of `nil` when absence should be explicit to the caller.
- Match on `Option` with `:Match`, `:IsSome`, or `:IsNone` instead of comparing the payload against `nil`.
- Keep the absence state in the container; do not throw away context by collapsing to raw `nil` too early.

---

## Guard Clause Failures

- Convert a guard failure into `Err` when the condition represents a real domain or application failure.
- Keep the value as `Option` when the failure means "no value was available" and the caller should inspect absence explicitly.
- Use `Result.guard(...)` only for early exit inside `Result.gen(...)`; it is control flow, not a business error carrier.
- Use `nil` only for short-lived local sentinels or implementation details that never cross the boundary.

---

## When Nil Is Acceptable

- Use `nil` for short-lived local variables and temporary sentinels inside a function.
- Use `nil` when the surrounding API already communicates failure or absence through another carrier, such as `Result`.
- Use `nil` when the value is a genuine internal "not present" state and no debugging context would be gained by wrapping it.
- Use `nil` for low-level implementation details that never cross a boundary and do not need explicit matching.

---

## Examples

```lua
-- Preferred: absence stays explicit
local target = Option.Wrap(self:_FindTarget(unitId))

if target:IsNone() then
    return Result.Err("TargetMissing", "No target was found for the unit")
end

local enemy = target:Unwrap()
```

```lua
-- Acceptable: local sentinel inside one function
local selectedUnit = nil
for _, unit in units do
    if unit.Id == unitId then
        selectedUnit = unit
        break
    end
end

if selectedUnit == nil then
    return Result.Err("UnitMissing", "No unit matched the requested id")
end
```

```lua
-- Avoid: raw nil loses the fact that this value is intentionally optional
local target = self:_FindTarget(unitId)
if target ~= nil then
    self:_FocusTarget(target)
end
```

---

## Prohibitions

- Do not use raw `nil` as the default representation for optional values when `Option` would preserve more information.
- Do not unwrap an `Option` unless the caller has already proven the `Some` case.
- Do not introduce `Option` for every temporary local variable; that adds ceremony without improving clarity.
- Do not replace a domain-level absence contract with ad hoc `nil` checks at every call site.

---

## Failure Signals

- A function returns `nil` and the caller cannot tell whether the value was missing, uninitialized, or intentionally absent.
- Debugging requires guessing why a value disappeared instead of inspecting `Option.Some` versus `Option.None`.
- Call sites spread `~= nil` checks across the codebase for the same conceptual absence.

---

## Checklist

- [ ] Boundaries that may omit a value return `Option` instead of raw `nil`.
- [ ] Call sites match or inspect the option state explicitly.
- [ ] `nil` is only used where the absence is local, obvious, or already encoded elsewhere.
- [ ] The chosen representation preserves enough context to debug missing-value cases quickly.
