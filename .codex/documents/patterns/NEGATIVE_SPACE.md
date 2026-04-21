# Negative Space Programming

Negative space programming means explicitly defining and handling every failure case — not just the happy path. For a multiplayer game, bad data can corrupt state, break sync, or cause subtle bugs that are nearly impossible to trace after the fact.

The core idea: **define what must NOT happen as clearly as what should happen.**

---

## The Four Practices

1. **Validate preconditions** — assert what must be true before proceeding
2. **Fail fast with clear messages** — don't let bad data propagate silently
3. **Return explicit error states** — make failures observable
4. **Handle all edge cases** — think about what can go wrong, not just what should work

---

## By Layer

### Value Objects — Assertions for Preconditions

Value objects use `assert()` to validate construction inputs. These represent programmer errors — things that should never happen in correct code.

```lua
function EntityId.new(value: number)
    assert(type(value) == "number", "ID must be a number")
    assert(value > 0, "ID must be positive")
    assert(math.floor(value) == value, "ID must be an integer")

    local self = setmetatable({}, EntityId)
    self.Id = value
    return table.freeze(self)
end
```

If an assert fires, it means something upstream is broken — not that the user gave bad input.

---

### Domain Validators — Converting Assertions to Errors

Domain validators wrap value object construction in `pcall()` to catch assertion failures and convert them into user-friendly error strings. They accumulate all errors before returning so callers get comprehensive feedback.

```lua
function Validator:ValidateEntity(name: string, entityType: string): (boolean, { string })
    local errors = {}

    local ok = pcall(function()
        EntityName.new(name)
    end)
    if not ok then
        table.insert(errors, Errors.INVALID_NAME)
    end

    if not self:_IsValidType(entityType) then
        table.insert(errors, Errors.INVALID_TYPE)
    end

    return #errors == 0, errors
end
```

**Always accumulate** — don't return on the first error. Give the caller everything that's wrong at once.

---

### Application Services — Multi-Layer Validation

Validate at every boundary. Each `Execute()` method checks inputs, checks business state, then executes — with an explicit early return at each failure point.

```lua
function Execute:Execute(userId: number, data: TData): (boolean, TResult | string)
    -- Layer 1: raw input validity
    if not userId or userId <= 0 then
        warn("[Context:Service] userId:", userId, "- Invalid userId")
        return false, "Invalid user"
    end

    -- Layer 2: business state validity
    local valid, errors = self.Validator:Validate(data)
    if not valid then
        warn("[Context:Service] userId:", userId, "- Validation failed:", table.concat(errors, ", "))
        return false, table.concat(errors, ", ")
    end

    -- Layer 3: execution (wrapped to catch unexpected failures)
    local success, result = pcall(function()
        return self:_Execute(data)
    end)
    if not success then
        warn("[Context:Service] userId:", userId, "- Execution failed:", result)
        return false, "Operation failed"
    end

    return true, result
end
```

**Logging format**: `[ContextName:ServiceName] userId: X - description`

---

### Context Layer — Pure Pass-Through

Context methods never log and never add logic. They are bridges. The Application layer already logged at the source — logging again here would be noise with less context.

```lua
function Context:DoSomething(userId: number, data: any): (boolean, TResult | string)
    return self.ExecuteService:Execute(userId, data)
end
```

---

## Centralized Error Constants

Error messages live in a per-context `Errors.lua`. Never write error strings inline in service code.

```lua
-- [ContextName]/Errors.lua
return table.freeze({
    INVALID_ID    = "Entity ID does not exist",
    INVALID_NAME  = "Name must be 3-20 characters",
    DUPLICATE     = "Entity already exists",
    STATE_INVALID = "Entity is in an invalid state",
})
```

---

## Checklist

**Value Objects:**
- [ ] Assert type and value constraints with clear messages
- [ ] `table.freeze(self)` at end of `.new()`

**Domain Validators:**
- [ ] Wrap Value Object construction in `pcall()`
- [ ] Return `(success: boolean, errors: { string })`
- [ ] Accumulate all errors — don't short-circuit on first failure

**Application Services:**
- [ ] Validate raw inputs at top of `Execute()`
- [ ] Return `(success: boolean, data | error)`
- [ ] Explicit early return for every failure path
- [ ] Use constants from `Errors.lua` — no inline strings
- [ ] Log at source: `[Context:Service] userId: X - message`

**Context Layer:**
- [ ] Pure pass-through — no logic, no logging
- [ ] Propagate errors unchanged
