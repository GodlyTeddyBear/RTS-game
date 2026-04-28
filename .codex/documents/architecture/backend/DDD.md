# Domain-Driven Design (DDD)

## Overview

Every bounded context has exactly three layers with strict dependency rules:

```text
Application Layer
      ^
Domain Layer
      ^
Infrastructure Layer
```

- A lower layer never depends on a layer above it.
- The Domain layer owns pure business logic.
- The Application layer orchestrates domain and infrastructure work.
- The Infrastructure layer owns technical implementation details.

---

## Layer Responsibilities

### Domain Layer (`[ContextName]Domain/`)

- Pure business logic.
- No framework knowledge.
- No side effects.
- **Services**: validators and calculators that receive read-only input and return result objects.
- **Specs**: composable eligibility rules, module-level constants, and pure predicates.
- **Policies**: fetch state from Infrastructure, build candidates, and evaluate specs; see [POLICIES_AND_SPECS.md](POLICIES_AND_SPECS.md).
- **ValueObjects**: immutable self-validating domain concepts.
- Never modifies input parameters.
- No dependencies on JECS, ProfileStore, Knit, or any external system.
- Policies may depend on Infrastructure for reads.

```lua
-- Domain service returns a result object and never mutates input.
function Calculator:Execute(target)
    local newValue = math.max(0, target.Value - 10)
    return { TargetId = target.Id, NewValue = newValue }
end
```

### Application Layer (`Application/Services/`)

- Orchestrates domain and infrastructure services.
- Calls domain services to calculate or validate, then infrastructure to persist or sync.
- Returns `Result<T>` values consistently.
- Logs errors at the source with full context; this is the only layer that logs.

```lua
function CreateItemService:Execute(userId, itemId, quantity)
    local validation = self.Validator:ValidateItemCreation(itemId, quantity)
    if validation:Fail() then
        return Result.Err(validation:Error())
    end

    local entityId = self.Factory:CreateItem(itemId, quantity)
    self.SyncService:AddItemToUser(userId, entityId, itemId, quantity)
    return Result.Ok(entityId)
end
```

### Infrastructure Layer (`Infrastructure/`)

- Technical implementation: JECS entity creation, ProfileStore persistence, Charm atom sync, and ECS game-object sync.
- Provides centralized mutation methods; all atom updates go through here.
- Never called by the Domain layer.
- Organized into three subfolders:
  - `ECS/` for JECS world singletons, component registries, and entity factories.
  - `Persistence/` for ProfileStore read/write, Charm atom sync services, and ECS game-object sync services.
  - `Services/` for everything else, including Roblox instance manipulation and game logic.

---

## Bounded Context Structure

```text
Contexts/
`-- [ContextName]/
    |-- [ContextName]Context.lua     # Knit service - pure pass-through bridge
    |-- Application/
    |   |-- Commands/                # Write operations (full DDD stack)
    |   `-- Queries/                 # Read operations (Infrastructure only)
    |-- [ContextName]Domain/
    |   |-- Services/                # Validators, calculators (Commands only)
    |   |-- Specs/                   # Composable eligibility rules
    |   |-- Policies/                # State fetch + spec evaluation
    |   `-- ValueObjects/            # Immutable domain objects
    |-- Infrastructure/
    |   |-- ECS/                     # JECS world, component registries, entity factories
    |   |-- Persistence/             # ProfileStore, Charm atom sync, ECS game-object sync
    |   `-- Services/                # Roblox instance work, game logic services
    |-- Config/                      # Configuration constants
    `-- Errors.lua                   # Centralized error message constants
```

See [CQRS.md](CQRS.md) for the command/query separation rules.

### Adding a New Bounded Context

1. Create `src/ServerScriptService/Contexts/[ContextName]/`.
2. Create subdirectories: `Application/Commands/`, `Application/Queries/`, `[ContextName]Domain/Services/`, `[ContextName]Domain/ValueObjects/`, `Infrastructure/ECS/`, `Infrastructure/Persistence/`, `Infrastructure/Services/`, and `Config/`. Only create the Infrastructure subfolders the context needs.
3. Create `[ContextName]Context.lua` as the main Knit service entry point with a `BaseContext` wrapper.
4. Create `Errors.lua` for centralized error constants.
5. Declare the context-owned module layers and wire `BaseContext.new(<ContextService>)`.
6. Knit auto-discovers and loads all services.

---

## Constructor Injection

- Services receive all dependencies via `.new()`.
- This enforces layer separation and makes services testable.
- Never reach into global state to get dependencies; always inject them.

```lua
local CreateItemService = {}
CreateItemService.__index = CreateItemService

function CreateItemService.new(validator, factory, syncService)
    local self = setmetatable({}, CreateItemService)
    self.Validator = validator -- Domain service
    self.Factory = factory -- Infrastructure service
    self.SyncService = syncService -- Infrastructure service
    return self
end
```

---

## Immutable Domain Services

- Domain services must be pure functions.
- They return result objects describing what should change.
- They never mutate state.
- The Application layer receives the result and applies it via the sync service.

**Wrong:**

```lua
function Calculator:Execute(target)
    target.Value = target.Value - 10 -- Direct mutation of input.
end
```

**Correct:**

```lua
function Calculator:Execute(target)
    local newValue = math.max(0, target.Value - 10)
    return { TargetId = target.Id, NewValue = newValue }
end
```

---

## Value Objects

- Value objects are immutable domain objects that encapsulate validation.
- Use `assert()` in the constructor; they represent preconditions that should never fail in correct code.
- Use them for primitive values with validation rules, domain concepts that are not entities, and values that need business logic.
- Do not use them for complex entities with multiple responsibilities or mutable state that changes over time.

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

---

## Context Layer

- The `[ContextName]Context.lua` Knit service is a pure bridge.
- It delegates to Application services.
- It never logs or adds logic.

```lua
function Context:DoSomething(userId: number, data: any): (boolean, TResult | string)
    return self.ExecuteService:Execute(userId, data)
end
```

See [ERROR_HANDLING.md](ERROR_HANDLING.md) for why logging belongs only in the Application layer.

---

## Cross-Context Communication

- Cross-context calls follow the same `Result` contract as intra-context calls.
- Inside a `Catch` boundary, use `Try()` for both Application `Execute()` calls and cross-context public method calls that return `Result<T>`.

**Intra-context** - calling your own Application services inside a `Catch` block:

```lua
-- Application services return Result - use Try() to propagate failures.
return Catch(function()
    local lotId = Try(self.SpawnLotService:Execute(player, cframe))
    return Result.Ok({ LotId = lotId })
end, handler)
```

**Cross-context** - calling another context's method:

```lua
-- Other contexts expose Result-returning public methods.
-- Use Try() to propagate failures across context boundaries.
return Catch(function()
    local claimResult = Try(self.WorldContext:ClaimLotArea(player))
    local lotId = Try(self.SpawnLotService:Execute(player, claimResult.CFrame))
    return Result.Ok({ LotId = lotId })
end, handler)
```

- Each context method owns a `Catch` and returns `Result<T>`.
- Callers can compose context operations with `Try()` and keep typed `Err` propagation end to end.
