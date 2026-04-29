---
name: new-service
description: Read when you need this skill reference template and workflow rules.
---

# New Service

<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Add a new backend module to an existing bounded context.

`$ARGUMENTS` format: `<ContextName> <Kind> <Name>`

- `<ContextName>`: existing context name in PascalCase (for example: `Worker`, `World`)
- `<Kind>`: one of `ApplicationCommand`, `ApplicationQuery`, `DomainPolicy`, `DomainService`, `DomainSpecs`, `DomainValueObject`, `InfrastructureService`, `InfrastructurePersistence`, `InfrastructureECS`
- `<Name>`: module name in PascalCase (for example: `HireWorker`, `FindAvailableLots`, `AssignRolePolicy`)


---

## What to do

1. Read `src/ServerScriptService/Contexts/<ContextName>/` and `<ContextName>Context.lua` before creating anything.
2. Read `src/ServerScriptService/Contexts/<ContextName>/Errors.lua` and reuse existing error constants.
3. Read `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua` and reuse existing context-shared types.
4. Read persistence lifecycle contracts:
   - `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua`
   - `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua`
5. Read `.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md` and `.codex/documents/architecture/backend/ERROR_HANDLING.md` and follow their BaseApplication/Result contracts for the selected layer.
6. Create exactly one module at the target path for the selected `<Kind>`.
7. If a new context-shared shape is needed, add it to `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua` instead of defining it locally across multiple files.
8. Wire it in `'<ContextName>Context.lua'` when required (require + registry register + cached reference if used).
9. Report what was created and what wiring was added.


---

## Paths by kind

- `ApplicationCommand` -> `src/ServerScriptService/Contexts/<ContextName>/Application/Commands/<Name>.lua`
- `ApplicationQuery` -> `src/ServerScriptService/Contexts/<ContextName>/Application/Queries/<Name>.lua`
- `DomainPolicy` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/Policies/<Name>.lua`
- `DomainService` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/Services/<Name>.lua`
- `DomainSpecs` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/Specs/<Name>.lua`
- `DomainValueObject` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/ValueObjects/<Name>.lua`
- `InfrastructureService` -> `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Services/<Name>.lua`
- `InfrastructurePersistence` -> `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Persistence/<Name>.lua`
- `InfrastructureECS` -> `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/ECS/<Name>.lua`
- **Any `*SyncService` must use `InfrastructurePersistence` and live under `Infrastructure/Persistence/` (never `Infrastructure/Services/`).**
- ECS infrastructure modules should prefer the ECS base classes:
  - `BaseECSWorldService` for world ownership
  - `BaseECSComponentRegistry` for component/tag registration
  - `BaseECSEntityFactory` for entity mutation and queries
  - `BaseSyncService` for atom-backed sync services that bridge ECS state
- Shared utilities should still be preferred for reusable technical work inside ECS and non-ECS modules:
  - `SpatialQuery` for raycasts, overlap checks, range checks, visibility, and target picking
  - `PlacementPlus` for placement previews, snapping, footprints, ground alignment, and placement validation
  - `ModelPlus` for model pivots, bounds, movement, alignment, and model traversal


---

## Boilerplate by kind

### Result Contract By Kind

- `ApplicationCommand`: must require `Result`, return `Result.Result<T>` from `Execute`, and use `Ensure` + `Try` for guard/propagation.
- `ApplicationQuery`: must require `Result`, return `Result.Result<T>` from `Execute`, and use inline `Ensure` guards. Queries never require Domain.
- `DomainPolicy`: must require `Result`, return `Result.Result<T>` from `Check`, and use `Try(spec:IsSatisfiedBy(candidate))` for command-invoked policy checks.
- `DomainService`: default to Result-returning shape (`Result.Result<T>`) so validators can use `TryAll` and callers can use `Try`.
- `InfrastructureService` / `InfrastructurePersistence` / `InfrastructureECS`: use `Result` for genuinely fallible runtime boundaries (`fromPcall`, `fromNilable`); use plain Lua returns for safe in-memory reads where `nil` is valid.

### Type Contract

- Context-shared data shapes must live in `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`.
- New modules should import that file (for example: `local <ContextName>Types = require(ReplicatedStorage.Contexts.<ContextName>.Types.<ContextName>Types)`), then alias needed types locally.
- Keep module-private helper types local only when they are truly internal implementation details.

### Persistence Event Contract

- Context persistence behavior is driven by `GameEvents.Events.Persistence` (`ProfileLoaded`, `ProfileSaving`, `PlayerReady`).
- `InfrastructurePersistence` modules should expose explicit load/save methods that context handlers call from those event hooks.
- Do not implement profile hydration/save flows by directly binding persistence logic to `Players.PlayerAdded/PlayerRemoving` inside feature modules.
- Sync services that own atom mutation/read APIs are persistence infrastructure and must be placed in `Infrastructure/Persistence`.

### ApplicationCommand

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local <ContextName>Types = require(ReplicatedStorage.Contexts.<ContextName>.Types.<ContextName>Types)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseCommand)

export type T<Name> = typeof(setmetatable(
    {} :: {
        -- Injected dependencies
    },
    <Name>
))

function <Name>.new(): T<Name>
    local self = BaseCommand.new("<ContextName>", "<Name>")
    return setmetatable(self, <Name>)
end

function <Name>:Init(registry: any, _name: string)
    -- self:_RequireDependencies(registry, {
    --     _someDependency = "SomeDependency",
    -- })
end

function <Name>:Execute(...: any): Result.Result<any>
    return Result.Catch(function()
        -- 1) Validate/guard inputs
        Ensure(true, "NotImplemented", "Replace with real guard condition")

        -- 2) Domain policy/service checks
        -- local policyData = Try(self.SomePolicy:Check(...))
        -- local request: <ContextName>Types.SomeRequest = ...

        -- 3) Infrastructure mutation/persist/sync
        -- Try(self.SomePersistenceService:Save(...))

        return Ok(table.freeze({}))
    end, self:_Label())
end

return <Name>
```

### ApplicationQuery

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)
local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local <ContextName>Types = require(ReplicatedStorage.Contexts.<ContextName>.Types.<ContextName>Types)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseQuery)

export type T<Name> = typeof(setmetatable(
    {} :: {
        -- Infrastructure dependencies only
    },
    <Name>
))

function <Name>.new(): T<Name>
    local self = BaseQuery.new("<ContextName>", "<Name>")
    return setmetatable(self, <Name>)
end

function <Name>:Init(registry: any, _name: string)
    -- self:_RequireDependency(registry, "_syncService", "SomeSyncService")
end

function <Name>:Execute(...: any): Result.Result<any>
    return Ok(table.freeze({
        -- Inline structural guards (queries do not use Domain validators)
        -- Ensure(true, "NotImplemented", "Replace with real guard condition")

        -- Read-only infrastructure calls
        -- local data = Try(self.SomeReadService:Get(...)) -- if read can fail
        -- local response: <ContextName>Types.SomeResponse = ...
    }))
end

return <Name>
```

### DomainPolicy

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try
local <ContextName>Types = require(ReplicatedStorage.Contexts.<ContextName>.Types.<ContextName>Types)

local <ContextName>Specs = require(script.Parent.Parent.Specs.<ContextName>Specs)

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable(
    {} :: {
        -- Infrastructure dependencies used for reads
    },
    <Name>
))

function <Name>.new(): T<Name>
    local self = setmetatable({}, <Name>)
    return self
end

function <Name>:Init(registry: any, _name: string)
    -- self.Registry = registry:Get("SomeInfrastructureService")
end

function <Name>:Check(...: any): Result.Result<any>
    local candidate = {
        -- Build typed candidate from infrastructure reads
    }

    Try(<ContextName>Specs.CanRun:IsSatisfiedBy(candidate))

    return Ok(table.freeze({
        -- Return fetched state needed by caller
    }))
end

return <Name>
```

### DomainService

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable({}, <Name>))

function <Name>.new(): T<Name>
    local self = setmetatable({}, <Name>)
    return self
end

function <Name>:Execute(input: any): Result.Result<any>
    -- Pure domain logic, no side effects, no framework deps
    -- For validators, prefer composing checks with TryAll(...)
    return Ok(table.freeze({
        Input = input,
    }))
end

return <Name>
```

### DomainSpecs

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

export type TCandidate = {
    -- Fields used by composed specs
}

local RuleA = Spec.new("RuleAFailed", Errors.<ERROR_CONSTANT_A>, function(ctx: TCandidate)
    return true
end)

local RuleB = Spec.new("RuleBFailed", Errors.<ERROR_CONSTANT_B>, function(ctx: TCandidate)
    return true
end)

local CanRun = Spec.All({ RuleA, RuleB })

return table.freeze({
    CanRun = CanRun,
})
```

### DomainValueObject

```lua
--!strict

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable(
    {} :: {
        Value: string,
    },
    <Name>
))

function <Name>.new(value: string): T<Name>
    assert(type(value) == "string", "Value must be a string")
    assert(value ~= "", "Value must not be empty")

    local self = setmetatable({}, <Name>)
    self.Value = value
    return table.freeze(self)
end

function <Name>:GetValue(): string
    return self.Value
end

return <Name>
```

### InfrastructureService / InfrastructurePersistence / InfrastructureECS

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, fromNilable, fromPcall = Result.Ok, Result.Try, Result.fromNilable, Result.fromPcall

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable(
    {} :: {
        -- Injected infrastructure dependencies
    },
    <Name>
))

function <Name>.new(...: any): T<Name>
    local self = setmetatable({}, <Name>)
    return self
end

function <Name>:Init(registry: any, _name: string)
    -- Optional registry wiring
end

-- Use Result for runtime-boundary failures.
-- Use plain Lua returns for safe in-memory reads where nil is valid.
function <Name>:Load(...: any): Result.Result<any>
    -- return fromPcall("ExternalCallFailed", SomeApi.Call, SomeApi, ...)
    -- local data = Try(fromNilable(value, "MissingData", "Expected data was nil"))
    return Ok(table.freeze({}))
end

return <Name>
```

### ECS Base Classes

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)
local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)

local <ContextName>ECSWorldService = {}
<ContextName>ECSWorldService.__index = <ContextName>ECSWorldService
setmetatable(<ContextName>ECSWorldService, { __index = BaseECSWorldService })

function <ContextName>ECSWorldService.new()
    return setmetatable(BaseECSWorldService.new("<ContextName>"), <ContextName>ECSWorldService)
end

local <ContextName>ComponentRegistry = {}
<ContextName>ComponentRegistry.__index = <ContextName>ComponentRegistry
setmetatable(<ContextName>ComponentRegistry, { __index = BaseECSComponentRegistry })

function <ContextName>ComponentRegistry.new()
    return setmetatable(BaseECSComponentRegistry.new("<ContextName>"), <ContextName>ComponentRegistry)
end

local <ContextName>EntityFactory = {}
<ContextName>EntityFactory.__index = <ContextName>EntityFactory
setmetatable(<ContextName>EntityFactory, { __index = BaseECSEntityFactory })

function <ContextName>EntityFactory.new()
    return setmetatable(BaseECSEntityFactory.new("<ContextName>"), <ContextName>EntityFactory)
end

local <ContextName>SyncService = {}
<ContextName>SyncService.__index = <ContextName>SyncService
setmetatable(<ContextName>SyncService, { __index = BaseSyncService })

function <ContextName>SyncService.new()
    return setmetatable({}, <ContextName>SyncService)
end

return <ContextName>ECSWorldService
```


---

## Wiring rules

- Register new modules in `<ContextName>Context.lua` using the correct category:
  - `ApplicationCommand` / `ApplicationQuery` -> `"Application"`
  - `DomainPolicy` / `DomainService` / `DomainSpecs` / `DomainValueObject` -> `"Domain"` only if it is a runtime service that needs registry init; specs and value objects usually are not registry-registered
  - `InfrastructureService` / `InfrastructurePersistence` / `InfrastructureECS` -> `"Infrastructure"`
  - `ApplicationCommand` and `ApplicationQuery` modules should inherit from `BaseCommand` and `BaseQuery` respectively.
  - `InfrastructureECS` modules should use the ECS base classes when they own world, registry, entity, or sync behavior.
- Queries must not depend on Domain modules.
- Commands may depend on Domain + Infrastructure.
- Domain services are pure and must not require Knit, JECS, ProfileStore, Charm, or Roblox instance APIs for side effects.
- Infrastructure is the only layer that mutates sync state.
- If wiring a new public server-to-server method in `<ContextName>Context.lua`, return `Result.Result<T>` from the method boundary and preserve propagation.
- Reserve `result:unwrapOr(default)` for terminal/private boundaries where fallback behavior is explicitly required.


---

## Rules

- Do not create `Application/Services/` (deprecated).
- All files start with `--!strict`.
- Reuse `Errors.lua` constants; do not add inline error strings.
- Use constructor + `Init(registry, _name)` pattern for registry-managed services.
- Keep context methods as pass-through bridges; no business logic in `'<ContextName>Context.lua'`.
- Treat Result usage as mandatory by layer (see Result contract section above), not optional style.
- Keep context-shared type definitions centralized in `<ContextName>Types.lua`; do not duplicate the same shape in multiple modules.
