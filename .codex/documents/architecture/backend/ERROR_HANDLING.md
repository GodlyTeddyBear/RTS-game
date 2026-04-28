# Error Handling

## Overview
- Use `Result` for operations that can genuinely fail at runtime.
- Use plain Lua when `nil` is valid absence or when a precondition already guarantees success.
- Keep error logging at the Application layer; Context code should only wrap work in `Catch`.
- Store error strings in per-context `Errors.lua` files.

---

## Core Rules
- `Err` represents expected business failure.
- `Defect` represents an unexpected crash and is created automatically by `Catch` in most cases.
- `Catch` is the outer boundary for a context method and always returns `Result<T>`.
- `Try` unwraps a `Result` inside `Catch`.
- `Ensure` is the inline guard for application code and replaces `if` / `return Err` blocks.
- `TryAll` accumulates validation failures instead of short-circuiting.
- `fromNilable` should be used whenever `nil` is a real failure.
- Public server-to-server context methods should return `Result<T>` so callers can keep propagating failures.
- `.Client` methods should call `Catch` only when they invoke `Execute` directly.
- Do not inline error strings.

---

## Primitives

### Constructors
| Function | Purpose |
|---|---|
| `Ok(value)` | Wraps a success value |
| `Err(type, message, data?)` | Wraps an expected business failure with structured context |
| `Defect(message, traceback?)` | Wraps an unexpected crash; bypasses `orElse` and is logged as an error |
| `TryAll(...)` | Accumulates multiple Results; `Ok` with all values or `Err` with all failures. Defects dominate and short-circuit |
| `fromPcall(errType, fn, ...)` | Converts a Roblox `pcall`-style API call into a Result |
| `fromNilable(value, errType, msg, data?)` | Converts a nil-able value into a Result |
| `Catch(fn, label, failureHandler?, ...)` | `xpcall` boundary that logs on failure, calls an optional handler, and always returns `Result<T>` |

### Throwable
- Use inside `Catch`.
- Return plain values and throw on failure.

| Function | Purpose |
|---|---|
| `Try(result)` | Unwraps `Ok` or throws the `Err` as an exception |
| `Ensure(condition, type, msg, data?)` | Asserts a condition or throws `Err`; inline guard replacing `if` / `return Err` blocks |
| `RequirePath(root, ...)` | Walks nested string keys on a table; throws `Err("MissingPath")` if any key is nil |

### Chainable methods
- Return `Result`.
- Can continue chaining.

| Method | Purpose |
|---|---|
| `result:andThen(fn)` | Transforms an `Ok` value; `fn` must return a `Result` |
| `result:orElse(fn)` | Recovers from business `Err`; `fn` receives the `Err` and must return a `Result` |
| `result:tapError(fn)` | Side effect on any failure (`Err` or `Defect`) |
| `result:tap(fn)` | Side effect on `Ok` only |
| `result:tapBoth(onOk, onErr)` | Side effect on any outcome |
| `result:mapError(fn)` | Transforms business `Err`; `fn` must return an `Err` |
| `result:filter(pred, type, msg, data?)` | Converts `Ok` to `Err` if the predicate is falsy |
| `result:filterOrElse(pred, fn)` | Like `filter` but builds the `Err` from the rejected value |

### Terminal methods
- Return plain values and end the Result chain.

| Method | Purpose |
|---|---|
| `result:map(fn)` | Unwraps `Ok` and applies `fn`; throws on `Err` |
| `result:unwrapOr(default)` | Extracts the `Ok` value or returns the default |

### Combinators
| Function | Purpose |
|---|---|
| `Result.zip(resultA, resultB)` | Combines two Results into `Ok({a, b})`; short-circuits on first failure |
| `Result.zipWith(resultA, resultB, fn)` | Like `zip` but merges both `Ok` values via `fn` |
| `Result.traverse(items, fn)` | Maps `fn` over a list and accumulates all Results |
| `Result.retry(fn, options)` | Retries a function up to `maxAttempts` times with optional `delay`; only retries on business `Err` |

### Async
- Return Promises.
- Bridge between Result and Promise systems.

| Function | Purpose |
|---|---|
| `Result.timeout(fn, seconds, errType?)` | Runs a yielding function; resolves with `Err` if it exceeds the duration |
| `Result.race(fns)` | Runs multiple yielding functions; resolves with the first Result to finish |
| `Result.all(fns)` | Runs multiple yielding functions concurrently; collects all Results into `Ok({...})` |

### Structured resource management
- Guarantees cleanup on any outcome.

| Function / Method | Purpose |
|---|---|
| `Result.scoped(fn)` | Runs `fn` with a `Scope`; flushes all registered cleanup via Janitor on exit, whether `fn` returned `Ok`, `Err`, or `Defect` |
| `Result.acquireRelease(acquire, release, use)` | Acquires a resource, uses it, then releases it; `release` always runs, even on failure |
| `scope:add(resource, cleanupFn)` | Registers any resource with a custom cleanup function |
| `scope:addJanitorItem(obj, methodName?)` | Registers any Janitor-trackable object |
| `scope:addPromise(promise)` | Registers a Promise and cancels it automatically if the scope exits before it resolves |

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

    scope:addPromise(loadAssetsAsync()) -- cancelled if scope exits early

    return exportData(conn, file)
end)
```

### Inspection
| Function | Purpose |
|---|---|
| `Result.sandbox(result)` | Wraps any Result in `Ok`; makes it inert so `andThen`, `orElse`, and `Try` will not react to it |
| `Result.unsandbox(sandboxed)` | Unwraps back into the error channel; propagation resumes |

### Control flow
- Pure control flow only; no error handling.

| Function | Purpose |
|---|---|
| `Result.guard(condition, returnValue?)` | Exits the current `gen` block early if condition is falsy |
| `Result.gen(fn, ...)` | Runs `fn` in a coroutine; returns `fn`'s return value or `guard`'s `returnValue` on early exit |

---

## Layer Responsibilities

### Infrastructure
- Return `Result` only when failure is real.
- Use `Result` for external calls such as DataStore, HTTP, workspace traversal, and JECS operations that can throw.
- Use `Result` for conditional failure on mutable state when missing data is a real failure.
- Use `Result` for multi-step mutations that can partially fail.
- Use plain Lua for in-memory reads where `nil` is valid absence.
- Use plain Lua for pure mutations when the Policy layer already guaranteed preconditions.

```lua
-- External call: can fail at runtime
function QuestPersistenceService:Load(player): Result<TQuestState>
    return fromPcall("DataStoreFailed", DataStore.GetAsync, DataStore, key)
end

-- Profile missing is a real failure, not a valid "not found"
-- Use fromNilable to convert nil -> Err in one line.
function QuestPersistenceService:Save(player, state): Result<boolean>
    local data = Try(fromNilable(ProfileManager:GetData(player), "PersistenceFailed", "No profile data"))
    data.Quest = deepClone(state)
    return Ok(true)
end
```

```lua
-- nil means "unclaimed" - not an error
function LotAreaRegistry:GetClaimant(areaName): Player?
    return self._areas[areaName] and self._areas[areaName].ClaimedBy or nil
end

-- Preconditions guaranteed by Policy - mutation always succeeds
function LotAreaRegistry:SetClaim(areaName, player)
    self._areas[areaName].ClaimedBy = player
end
```

- The Policy layer above Infrastructure uses `Ensure` to handle nil from plain returns.
- Infrastructure does not need to wrap valid absence in `Err`.

### Domain
- Return `Result`.
- Validators should use `TryAll` to accumulate all validation errors before returning.

```lua
function WorkerValidator:ValidateHiring(workerType: string): Result<nil>
    return TryAll(
        self:_ValidateType(workerType),
        self:_ValidateCapacity()
    )
end
```

### Application
- Use `Try` to unwrap Results.
- Use `Ensure` for inline condition guards.
- Return `Ok(value)` on success.
- Do not log in Application methods.

```lua
-- Correct: truthy check, no explicit nil comparison needed
Ensure(player, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)
Ensure(data, "PersistenceFailed", Errors.NO_PROFILE_DATA)

-- Avoid: redundant nil comparison
Ensure(player ~= nil, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)
```

```lua
function HireWorker:Execute(userId: number, workerType: string): Result<string>
    Ensure(userId > 0, "InvalidArgument", Errors.INVALID_USER_ID)
    Try(self.Validator:ValidateHiring(workerType))
    local entity = self.EntityFactory:CreateWorker(userId, workerType)
    Try(self.PersistenceService:SaveWorkerEntity(entity))
    self.SyncService:CreateWorker(userId, workerType)
    local workerId = entity.Id
    return Ok(workerId)
end
```

### Context
- Own a `Catch(fn, "Context:Method")` for each context method, or return `Ok(value)` directly for simple getters.
- Let the `Catch` label handle logging; do not add manual `warn()` calls.
- Return `Result<T>` from public server-to-server context methods so upstream callers can compose with `Try()` and preserve typed failures.

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
        return NPCContext:SpawnWave(combatId)
    end, "Combat:StartCombat")
end

-- Tick loops / event callbacks: terminal - just ignore the returned Result
function CombatContext:_OnTick()
    Catch(function()
        Try(self.ProcessTickService:Execute())
        return Ok(nil)
    end, "Combat:Tick")
end
```

### Getter methods
- Skip `Catch` when the method only reads init-time fields and cannot fail.
- Return `Ok(self.Field)` directly.

```lua
function NPCContext:GetWorld(): Result<any>
    return Ok(self.World)
end
```

- Callers in `KnitStart` that are not inside `Catch` should still handle the `Result` explicitly.

```lua
local worldResult = NPCContext:GetWorld()
if not worldResult.success then
    error(worldResult)
end
registry:Register("World", worldResult.value)
```

### Context `.Client` methods
- Treat `.Client` methods as server methods that return to the client through Knit's remote transport.
- Call `Catch` directly when the method invokes `Execute`.
- Delegate to `self.Server:Method()` without an extra `Catch` when the server method already owns the boundary.

```lua
function WorkerContext.Client:HireWorker(player: Player, workerType: string)
    local userId = player.UserId
    return Catch(function()
        return self.Server.HireWorker:Execute(userId, workerType)
    end, "Worker.Client:HireWorker")
end
```

```lua
function QuestContext.Client:DepartOnQuest(player, zoneId, partyAdventurerIds)
    return self.Server:DepartOnQuest(player, zoneId, partyAdventurerIds)
end
```

### Client controller
- Treat the client's promise `:catch` as the terminal boundary.

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

## Result Flow
```text
Infrastructure  ->  return Result
Application     ->  Try propagates (throws inside Catch's xpcall)
Context method  ->  Catch logs, returns Err (never throws)
Caller Catch    ->  detects Err via not result.success, returns Err
Knit remote     ->  WrapContext unwraps Ok or rejects promise on Err
Client :catch   ->  terminal boundary
```

- Each context in the chain logs its own label.
- The structured `Err` (type + message) flows upward by return value, never by exception.

---

## Result Chaining

### `:andThen(fn)`
- Transform the `Ok` value and stay in the Result system.
- `fn` must return a `Result`.

```lua
-- Extract a field from a fetched profile
local coinsResult = self.ProfileService:GetProfile(userId)
    :andThen(function(profile)
        return Ok(profile.Coins)
    end)
```

### `:orElse(fn)`
- Recover from a business `Err` and continue normally.
- `fn` receives the `Err` and must return a `Result`.

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

### `:unwrapOr(default)`
- Extract the value or use a default.
- Exits the Result system.

```lua
-- Optional data with sensible fallback
local multiplier = self.ConfigService:GetMultiplier(userId):unwrapOr(1)
local savedState = self.PersistenceService:Load(player):unwrapOr({})
```

### When to chain vs `Try`
| Situation | Use |
|---|---|
| Inside `Catch`, happy path must succeed | `Try(result)` |
| Inside `Catch`, inline condition guard | `Ensure(cond, type, msg)` |
| Result is optional with a fallback value | `result:unwrapOr(default)` |
| Need to transform before propagating | `result:andThen(fn)` then `Try()` |
| Need to relabel an error at a context boundary | `result:orElse(fn)` then `Try()` |

- Do not chain off `Try()`; it returns a plain value, not a Result.

---

## Assertions vs Validation

### `assert()`
- Use for programmer errors only.
- Use inside Value Objects and constructors.
- Treat failures as contract violations, not user input failures.

```lua
function ItemName.new(value: string)
    assert(type(value) == "string", "Name must be a string")
    assert(#value >= 1, "Name must not be empty")
    return table.freeze(setmetatable({ Name = value }, ItemName))
end
```

### `Err`
- Use for expected failures such as validation, missing data, and capacity limits.

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
- Store all error strings in a per-context `Errors.lua`.
- Never write error strings inline.

```lua
-- Contexts/Inventory/Errors.lua
return table.freeze({
    INVALID_ITEM_ID = "Item ID does not exist",
    INVALID_QUANTITY = "Quantity must be greater than zero",
    INVENTORY_FULL = "Inventory has reached max capacity",
})
```

---

## Checklist
- [ ] `Ok`, `Err`, `Defect`, `Try`, `Ensure`, and `Catch` are used with the right boundary.
- [ ] Infrastructure returns plain Lua for valid absence and pure mutations.
- [ ] Infrastructure uses `Result` only when failure is real.
- [ ] Application unwraps with `Try` and guards with `Ensure`.
- [ ] Context methods own a `Catch`, or return `Ok(value)` directly for simple getters.
- [ ] Public context methods propagate `Result` instead of unwrapping.
- [ ] `.Client` methods only add `Catch` when they call `Execute` directly.
- [ ] Error strings live in `Errors.lua` and are not inlined.

---

## Related Docs
- [BACKEND.md](BACKEND.md) - backend layer overview and routing
- [CQRS.md](CQRS.md) - command and query structure in the application layer
- [DDD.md](DDD.md) - DDD layer rules and bounded-context structure
- [STATE_SYNC.md](STATE_SYNC.md) - deep clone rules and centralized mutation pattern
- [SYSTEMS.md](SYSTEMS.md) - runtime systems, persistence flow, and library references
