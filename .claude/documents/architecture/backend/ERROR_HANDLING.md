# Error Handling

## Primitives

### Constructors (return Result — chainable)

| Function | Purpose |
|----------|---------|
| `Ok(value)` | Wraps a success value |
| `Err(type, message, data?)` | Wraps an expected business failure with structured context |
| `Defect(message, traceback?)` | Wraps an unexpected crash — bypasses `orElse`, logged as error. Created automatically by `Catch`; rarely used directly |
| `TryAll(...)` | Accumulates multiple Results; `Ok` with all values or `Err` with all failures. Defects dominate and short-circuit |
| `fromPcall(errType, fn, ...)` | Converts a Roblox pcall-style API call into a Result |
| `fromNilable(value, errType, msg, data?)` | Converts a nil-able value into a Result; `Ok(value)` if non-nil, `Err` if nil |
| `Catch(fn, label, failureHandler?, ...)` | `xpcall` boundary — logs on failure, calls optional handler, always returns `Result<T>` |

### Throwable (use inside Catch — return plain values, throw on failure)

| Function | Purpose |
|----------|---------|
| `Try(result)` | Unwraps `Ok` or throws the `Err` as an exception |
| `Ensure(condition, type, msg, data?)` | Asserts a condition or throws `Err` — inline guard replacing `if/return Err` blocks |
| `RequirePath(root, ...)` | Walks nested string keys on a table; throws `Err("MissingPath")` if any key is nil |

### Chainable methods (return Result — can continue chaining)

| Method | Purpose |
|--------|---------|
| `result:andThen(fn)` | Transforms `Ok` value — fn must return a `Result`. Passes `Err` through unchanged |
| `result:orElse(fn)` | Recovers from business `Err` — fn receives the `Err`, must return a `Result`. Passes `Ok` and defects through |
| `result:tapError(fn)` | Side-effect on any failure (`Err` or `Defect`); result passes through unchanged |
| `result:tap(fn)` | Side-effect on `Ok` value only; result passes through unchanged |
| `result:tapBoth(onOk, onErr)` | Side-effect on any outcome; result passes through unchanged |
| `result:mapError(fn)` | Transforms business `Err` — fn must return an `Err`. Passes `Ok` and defects through |
| `result:filter(pred, type, msg, data?)` | Converts `Ok` to `Err` if predicate is falsy; passes `Err` and defects through |
| `result:filterOrElse(pred, fn)` | Like `filter` but builds the `Err` from the rejected value via fn |

### Terminal methods (return plain values — end the chain)

| Method | Purpose |
|--------|---------|
| `result:map(fn)` | Unwraps `Ok` + applies fn; throws on `Err` (like `Try` + transform). Exits the Result system |
| `result:unwrapOr(default)` | Extracts `Ok` value or returns default. Safe, never throws. Exits the Result system |

### Combinators

| Function | Purpose |
|----------|---------|
| `Result.zip(resultA, resultB)` | Combines two Results into `Ok({a, b})`; short-circuits on first failure |
| `Result.zipWith(resultA, resultB, fn)` | Like `zip` but merges both Ok values via fn instead of a table |
| `Result.traverse(items, fn)` | Maps fn over a list and accumulates all Results (like `TryAll` over a mapped list) |
| `Result.retry(fn, options)` | Retries a function up to `maxAttempts` times with optional `delay`; only retries on business `Err` |

### Async (return Promises — bridge between Result and Promise systems)

| Function | Purpose |
|----------|---------|
| `Result.timeout(fn, seconds, errType?)` | Runs a yielding function; resolves with `Err` if it exceeds the duration |
| `Result.race(fns)` | Runs multiple yielding functions; resolves with the first Result to finish |
| `Result.all(fns)` | Runs multiple yielding functions concurrently; collects all Results into `Ok({...})` |

### Structured resource management (guaranteed cleanup on any outcome)

| Function / Method | Purpose |
|-------------------|---------|
| `Result.scoped(fn)` | Runs fn with a `Scope`; flushes all registered cleanup via Janitor on exit — whether fn returned `Ok`, `Err`, or `Defect` |
| `Result.acquireRelease(acquire, release, use)` | Acquires a resource, uses it, then releases it — `release` always runs, even on failure |
| `scope:add(resource, cleanupFn)` | Registers any resource with a custom cleanup function |
| `scope:addJanitorItem(obj, methodName?)` | Registers any Janitor-trackable object (Instance, connection, etc.) |
| `scope:addPromise(promise)` | Registers a Promise — cancelled automatically if the scope exits before it resolves |

Use `scoped` when an operation acquires multiple resources with different lifetimes. Use `acquireRelease` for the common single-resource acquire/use/release pattern.

```lua
-- Single resource: acquireRelease
Result.acquireRelease(
    function() return openDatabaseConnection() end,
    function(conn) conn:Close() end,
    function(conn) return conn:Query("SELECT * FROM players") end
)

-- Multiple resources: scoped
Result.scoped(function(scope)
    local conn = Try(openDatabaseConnection())
    scope:add(conn, function(c) c:Close() end)

    local file = Try(openFile("export.csv"))
    scope:add(file, function(f) f:Close() end)

    scope:addPromise(loadAssetsAsync())  -- cancelled if scope exits early

    return exportData(conn, file)
end)
```

### Inspection

| Function | Purpose |
|----------|---------|
| `Result.sandbox(result)` | Wraps any Result in `Ok` — makes it inert so `andThen`/`orElse`/`Try` won't react to it |
| `Result.unsandbox(sandboxed)` | Unwraps back into the error channel — propagation resumes |

### Control flow (pure control flow — no error handling)

| Function | Purpose |
|----------|---------|
| `Result.guard(condition, returnValue?)` | Exits the current `gen` block early if condition is falsy |
| `Result.gen(fn, ...)` | Runs fn in a coroutine; returns fn's return value or `guard`'s `returnValue` on early exit |

---

## Layer Responsibilities

### Infrastructure — return `Result` only when failure is real

Infrastructure uses `Result` when an operation crosses a runtime boundary that can genuinely fail. In-memory reads and pure mutations use plain Lua returns.

**Use `Result` for:**
- External system calls — DataStore, HTTP, workspace traversal, JECS operations that can throw
- Conditional failure on mutable state — e.g. profile data missing when it must exist
- Multi-step mutations that can partially fail

```lua
-- External call — can fail at runtime
function QuestPersistenceService:Load(player): Result<TQuestState>
    return fromPcall("DataStoreFailed", DataStore.GetAsync, DataStore, key)
end

-- Profile missing is a real failure, not a valid "not found"
-- Use fromNilable to convert nil → Err in one line (even a single nil check)
function QuestPersistenceService:Save(player, state): Result<boolean>
    local data = fromNilable(ProfileManager:GetData(player), "PersistenceFailed", "No profile data")
    Try(data)
    -- or inline: local data = Try(fromNilable(...))
    data.value.Quest = deepClone(state)
    return Ok(true)
end
```

Use `fromNilable` whenever a value may be nil and nil is a real failure — even for a single check. Prefer it over a manual `if not x then return Err(...) end` + `return Ok(x)` pair.

**Use plain Lua for:**
- In-memory reads where `nil` is a valid "not found" state
- Pure mutations where the Policy has already guaranteed preconditions
- Existence checks and simple lookups

```lua
-- nil means "unclaimed" — not an error
function LotAreaRegistry:GetClaimant(areaName): Player?
    return self._areas[areaName] and self._areas[areaName].ClaimedBy or nil
end

-- Preconditions guaranteed by Policy — mutation always succeeds
function LotAreaRegistry:SetClaim(areaName, player)
    self._areas[areaName].ClaimedBy = player
end
```

The Policy layer above Infrastructure uses `Ensure` to handle nil from plain returns. Infrastructure does not need to wrap valid absence in `Err`.

### Domain — return `Result`
Validators return `Ok` or `Err`. Use `TryAll` to accumulate all validation errors instead of short-circuiting.

```lua
function WorkerValidator:ValidateHiring(workerType: string): Result<nil>
    return TryAll(
        self:_ValidateType(workerType),
        self:_ValidateCapacity()
    )
end
```

### Application — use `Try` / `Ensure`, return `Result`
Commands and queries use `Try` to unwrap Results and `Ensure` for inline condition guards. Any failure throws immediately and propagates up to the nearest `Catch`. No logging here.

- `Try(result)` — unwrap a Result from a service call
- `Ensure(condition, type, msg)` — assert an inline condition (replaces if/return Err blocks)

`Ensure` accepts any truthy condition — pass the value directly rather than comparing to nil:

```lua
-- Correct — truthy check, no explicit nil comparison needed
Ensure(player, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)
Ensure(data, "PersistenceFailed", Errors.NO_PROFILE_DATA)

-- Avoid — redundant nil comparison
Ensure(player ~= nil, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)
```

```lua
function HireWorker:Execute(userId: number, workerType: string): Result<string>
    Ensure(userId > 0, "InvalidArgument", Errors.INVALID_USER_ID)
    Try(self.Validator:ValidateHiring(workerType))
    local entity = self.EntityFactory:CreateWorker(userId, workerType)
    Try(self.PersistenceService:SaveWorkerEntity(entity))
    self.SyncService:CreateWorker(userId, workerType)
    return Ok(workerId)
end
```

### Context — own a `Catch`, handler only logs
Every context method owns a `Catch`. The handler logs with the context label. `Catch` always returns `Result<T>` — propagation is automatic by return value. Use `Try()` inside the fn when you need to unwrap a success value to continue work.

```lua
-- Server-to-server: Err flows up automatically through return values
function NPCContext:SpawnWave(combatId: number): Result<nil>
    return Catch(function()
        Try(self.SpawnWaveService:Execute(combatId))
        return Ok(nil)
    end, "NPC:SpawnWave")
end

-- Caller: Err from SpawnWave flows through automatically
function CombatContext:StartCombat(combatId: number): Result<nil>
    return Catch(function()
        return NPCContext:SpawnWave(combatId)  -- Err propagates by return value
    end, "Combat:StartCombat")
end

-- Tick loops / event callbacks: terminal — just ignore the returned Result
function CombatContext:_OnTick()
    Catch(function()
        Try(self.ProcessTickService:Execute())
        return Ok(nil)
    end, "Combat:Tick")
    -- Catch returns Err, caller ignores it — no output, no crash
end
```

### Getter methods — skip `Catch`, return `Ok(value)` directly
Simple getters that access init-time fields cannot fail. No `Catch` needed.

```lua
function NPCContext:GetWorld(): Result<any>
    return Ok(self.World)
end
```

Callers in `KnitStart` (not inside a Catch) unwrap with `.value`:
```lua
registry:Register("World", NPCContext:GetWorld().value)
```

### Context `.Client` methods — own a `Catch` only when calling `Execute` directly
`.Client` methods are server methods — they run on the server and return to the client via Knit's remote transport. `WrapContext` wraps them and rejects the client promise on `Err`.

**Call `Execute` directly → own a `Catch`:**
```lua
function WorkerContext.Client:HireWorker(player: Player, workerType: string)
    local userId = player.UserId
    return Catch(function()
        return self.Server.HireWorker:Execute(userId, workerType)
    end, "Worker.Client:HireWorker")
end
```

**Delegate to a server method → no `Catch` needed** (the server method's `Catch` already runs):
```lua
function QuestContext.Client:DepartOnQuest(player, zoneId, partyAdventurerIds)
    return self.Server:DepartOnQuest(player, zoneId, partyAdventurerIds)
end
```

### Client Controller — terminal boundary
The client's promise `:catch` is the end of the chain.

```lua
KnitService:StartCombat(combatId)
    :andThen(function(result)
        -- handle success
    end)
    :catch(function(err)
        -- err.type, err.message from the originating context
    end)
```

---

## Propagation Chain

```
Infrastructure  →  return Result
Application     →  Try propagates (throws inside Catch's xpcall)
Context method  →  Catch logs, returns Err (never throws)
Caller Catch    →  detects Err via not result.success, logs its label, returns Err
Knit remote     →  WrapContext unwraps Ok or rejects promise on Err
Client :catch   →  terminal boundary
```

Each context in the chain logs its own label. The structured `Err` (type + message) flows upward by return value, never by exception.

---

## Result Chaining

Results support method-style chaining via `:andThen`, `:orElse`, and `:unwrapOr`. Use these **outside** a `Catch` boundary when the result is optional, has a fallback, or needs transforming at the call site. Inside a `Catch`, prefer `Try()` for the linear happy path.

### `:andThen(fn)` — transform the Ok value, stay in Result system
fn receives the unwrapped value and **must return a Result**.

```lua
-- Extract a field from a fetched profile
local coinsResult = self.ProfileService:GetProfile(userId)
    :andThen(function(profile)
        return Ok(profile.Coins)
    end)
```

### `:orElse(fn)` — recover from Err, continue normally
fn receives the Err and **must return a Result** (Ok to recover, Err to re-fail).

```lua
-- Re-label a cross-context error at the boundary
Try(self.InventoryContext:RemoveItem(userId, slot, qty)
    :orElse(function(err)
        return Err("CraftFailed", Errors.CRAFT_FAILED, { reason = err.message })
    end))

-- Recover with a default wrapped in Ok
local profile = self.ProfileService:GetProfile(userId)
    :orElse(function(_err)
        return Ok(DEFAULT_PROFILE)
    end)
```

### `:unwrapOr(default)` — extract value or use default, exits Result system
Returns a plain value, not a Result. No `Try()` needed after this.

```lua
-- Optional data with sensible fallback
local multiplier = self.ConfigService:GetMultiplier(userId):unwrapOr(1)
local savedState = self.PersistenceService:Load(player):unwrapOr({})
```

### When to chain vs when to `Try`

| Situation | Use |
|-----------|-----|
| Inside `Catch`, happy path must succeed | `Try(result)` |
| Inside `Catch`, inline condition guard | `Ensure(cond, type, msg)` |
| Result is optional with a fallback value | `result:unwrapOr(default)` |
| Need to transform before propagating | `result:andThen(fn)` then `Try()` |
| Need to re-label error at context boundary | `result:orElse(fn)` then `Try()` |

**Do NOT chain off `Try()`** — `Try()` returns a plain value, not a Result.

---

## Assertions vs Validation

### `assert()` — programmer errors only
Used in Value Objects and constructors. Represents a contract violation, not a user input failure.

```lua
function ItemName.new(value: string)
    assert(type(value) == "string", "Name must be a string")
    assert(#value >= 1, "Name must not be empty")
    return table.freeze(setmetatable({ Name = value }, ItemName))
end
```

### `Err` — expected failures
Used anywhere a failure is a normal outcome (validation, missing data, capacity limits).

```lua
function InventoryValidator:ValidateAddItem(itemId: string, quantity: number): Result<nil>
    if quantity <= 0 then
        return Err("InvalidQuantity", Errors.INVALID_QUANTITY)
    end
    return Ok(nil)
end
```

---

## Centralized Error Constants

Store all error strings in a per-context `Errors.lua`. Never write error strings inline.

```lua
-- Contexts/Inventory/Errors.lua
return table.freeze({
    INVALID_ITEM_ID   = "Item ID does not exist",
    INVALID_QUANTITY  = "Quantity must be greater than zero",
    INVENTORY_FULL    = "Inventory has reached max capacity",
})
```

---

## Negative Space Checklist

**Value Objects:**
- [ ] `assert()` all preconditions with clear messages
- [ ] `table.freeze()` the result

**Domain Services (Validators):**
- [ ] Return `Result` — `Ok(nil)` or `Err(type, message)`
- [ ] Use `TryAll` to accumulate all errors before returning

**Application Services:**
- [ ] Use `Try` to unwrap Results, `Ensure` for inline condition guards — no `if/return Err` blocks
- [ ] Return `Ok(value)` on success
- [ ] No logging

**Context Methods:**
- [ ] Own a `Catch(fn, "Context:Method")` (or return `Ok(value)` directly for simple getters)
- [ ] `Catch` logs automatically via the label — no manual `warn()` needed
- [ ] Callers detect propagation via `not result.success` on the returned `Result`

**Context `.Client` Methods:**
- [ ] Call `Execute` directly → wrap in `Catch(fn, "Context.Client:Method")`
- [ ] Delegate to `self.Server:Method()` → no `Catch` needed

**Client Controllers:**
- [ ] Use `:andThen` / `:catch` on the Knit promise
- [ ] `:catch` is the terminal boundary — no re-throw
