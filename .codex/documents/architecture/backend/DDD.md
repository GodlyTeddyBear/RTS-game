# Domain-Driven Design (DDD)

## Three Layers

Every bounded context has exactly three layers with strict dependency rules:

```
Application Layer
      ↓
Domain Layer
      ↓
Infrastructure Layer
```

A lower layer never depends on a layer above it.

---

## Layer Responsibilities

### Domain Layer (`[ContextName]Domain/`)

- Pure business logic — no framework knowledge, no side effects
- **Services**: Validators, calculators — receive read-only input, return result objects
- **Specs**: Composable eligibility rules — module-level constants, pure predicates
- **Policies**: Fetch state from Infrastructure, build candidates, evaluate specs — see [POLICIES_AND_SPECS.md](POLICIES_AND_SPECS.md)
- **ValueObjects**: Immutable self-validating domain concepts
- Never modifies input parameters
- No dependencies on JECS, ProfileStore, Knit, or any external system (Policies may depend on Infrastructure for reads)

```lua
-- Domain service returns a result object, never mutates
function Calculator:Execute(target)
    local newValue = math.max(0, target.Value - 10)
    return { TargetId = target.Id, NewValue = newValue }
end
```

### Application Layer (`Application/Services/`)

- Orchestrates domain + infrastructure services
- Calls domain services to calculate/validate, then infrastructure to persist/sync
- Returns `(success: boolean, data/error)` tuples consistently
- Logs errors at the source with full context — **this is the only layer that logs**

```lua
function CreateItemService:Execute(userId, itemId, quantity)
    local success, errors = self.Validator:ValidateItemCreation(itemId, quantity)
    if not success then
        return false, table.concat(errors, ", ")
    end
    local entityId = self.Factory:CreateItem(itemId, quantity)
    self.SyncService:AddItemToUser(userId, entityId, itemId, quantity)
    return true, entityId
end
```

### Infrastructure Layer (`Infrastructure/`)

- Technical implementation: JECS entity creation, ProfileStore persistence, Charm atom sync
- Provides centralized mutation methods — **all atom updates go through here**
- Never called by Domain layer
- Organized into three subfolders:
  - **`ECS/`** — JECS world singletons, component registries, entity factories
  - **`Persistence/`** — ProfileStore read/write and Charm atom sync services
  - **`Services/`** — Everything else (Roblox instance manipulation, game logic)

---

## Bounded Context Structure

```
Contexts/
└── [ContextName]/
    ├── [ContextName]Context.lua     # Knit service — pure pass-through bridge
    ├── Application/
    │   ├── Commands/                # Write operations (full DDD stack)
    │   └── Queries/                 # Read operations (Infrastructure only)
    ├── [ContextName]Domain/
    │   ├── Services/                # Validators, calculators (Commands only)
    │   ├── Specs/                   # Composable eligibility rules
    │   ├── Policies/                # State fetch + spec evaluation
    │   └── ValueObjects/            # Immutable domain objects
    ├── Infrastructure/
    │   ├── ECS/                     # JECS world, component registries, entity factories
    │   ├── Persistence/             # ProfileStore, Charm atom sync
    │   └── Services/                # Roblox instance work, game logic services
    ├── Config/                      # Configuration constants
    └── Errors.lua                   # Centralized error message constants
```

See [CQRS.md](CQRS.md) for the Command/Query separation rules.

### Adding a New Bounded Context

1. Create `src/ServerScriptService/Contexts/[ContextName]/`
2. Create subdirectories: `Application/Commands/`, `Application/Queries/`, `[ContextName]Domain/Services/`, `[ContextName]Domain/ValueObjects/`, `Infrastructure/ECS/`, `Infrastructure/Persistence/`, `Infrastructure/Services/`, `Config/` (only create the Infrastructure subfolders the context needs)
3. Create `[ContextName]Context.lua` — main Knit service entry point
4. Create `Errors.lua` — centralized error constants
5. Knit auto-discovers and loads all services

---

## Constructor Injection

Services receive all dependencies via `.new()`. This enforces layer separation and makes services testable.

```lua
local CreateItemService = {}
CreateItemService.__index = CreateItemService

function CreateItemService.new(validator, factory, syncService)
    local self = setmetatable({}, CreateItemService)
    self.Validator = validator       -- Domain service
    self.Factory = factory           -- Infrastructure service
    self.SyncService = syncService   -- Infrastructure service
    return self
end
```

Never reach into global state to get dependencies — always inject them.

---

## Immutable Domain Services

Domain services must be pure functions. They return result objects describing what should change; they never mutate state.

**Wrong:**
```lua
function Calculator:Execute(target)
    target.Value = target.Value - 10  -- Direct mutation of input!
end
```

**Correct:**
```lua
function Calculator:Execute(target)
    local newValue = math.max(0, target.Value - 10)
    return { TargetId = target.Id, NewValue = newValue }
end
```

The Application layer receives the result and applies it via the sync service.

---

## Value Objects

Immutable domain objects that encapsulate validation. Use `assert()` in the constructor — they represent preconditions that should never fail in correct code.

```lua
local UserId = {}
UserId.__index = UserId

function UserId.new(value: number)
    assert(type(value) == "number", "User ID must be a number")
    assert(value > 0, "User ID must be positive")
    assert(math.floor(value) == value, "User ID must be an integer")
    local self = setmetatable({}, UserId)
    self.Id = value
    return table.freeze(self)
end

function UserId:GetId(): number
    return self.Id
end

return UserId
```

**Use when:**
- Primitive values with validation rules (names, IDs)
- Domain concepts that aren't entities (coordinates, amounts)
- Values that need business logic (stat calculations, damage modifiers)

**Don't use when:**
- Complex entities with multiple responsibilities
- Mutable state that changes over time

---

## Context Layer (Pass-Through)

The `[ContextName]Context.lua` Knit service is a pure bridge — it delegates to Application services and never logs or adds logic.

```lua
function Context:DoSomething(userId: number, data: any): (boolean, TResult | string)
    return self.ExecuteService:Execute(userId, data)
end
```

See [ERROR_HANDLING.md](ERROR_HANDLING.md) for why logging belongs only in the Application layer.

---

## Cross-Context Communication

Cross-context calls (calling another context's public method) follow the same Result contract as intra-context calls.

**Intra-context** — calling your own Application services inside a `Catch` block:
```lua
-- Application services return Result — use Try() to propagate failures
return Catch(function()
    local lotId = Try(self.SpawnLotService:Execute(player, cframe))
    return Result.Ok({ LotId = lotId })
end, handler)
```

**Cross-context** — calling another context's method:
```lua
-- Other contexts expose Result-returning public methods.
-- Use Try() to propagate failures across context boundaries.
return Catch(function()
    local claimResult = Try(self.WorldContext:ClaimLotArea(player))
    local lotId = Try(self.SpawnLotService:Execute(player, claimResult.CFrame))
    return Result.Ok({ LotId = lotId })
end, handler)
```

**Why this works:** each context method owns a `Catch` and returns `Result<T>`. Callers can compose context operations with `Try()` and keep typed `Err` propagation end-to-end.

**Rule: inside a `Catch` boundary, use `Try()` for both Application `Execute()` calls and cross-context public method calls that return `Result<T>`.**
