Add a new backend module to an existing bounded context.

`$ARGUMENTS` format: `<ContextName> <Kind> <Name>`

- `<ContextName>`: existing context name in PascalCase (for example: `Worker`, `World`)
- `<Kind>`: one of `ApplicationCommand`, `ApplicationQuery`, `DomainPolicy`, `DomainService`, `DomainSpecs`, `DomainValueObject`, `InfrastructureService`, `InfrastructurePersistence`, `InfrastructureECS`
- `<Name>`: module name in PascalCase (for example: `HireWorker`, `FindAvailableLots`, `AssignRolePolicy`)

## What to do

1. Read `src/ServerScriptService/Contexts/<ContextName>/` and `<ContextName>Context.lua` before creating anything.
2. Read `src/ServerScriptService/Contexts/<ContextName>/Errors.lua` and reuse existing error constants.
3. Create exactly one module at the target path for the selected `<Kind>`.
4. Wire it in `'<ContextName>Context.lua'` when required (require + registry register + cached reference if used).
5. Report what was created and what wiring was added.

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

## Boilerplate by kind

### ApplicationCommand

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable(
    {} :: {
        -- Injected dependencies
    },
    <Name>
))

function <Name>.new(): T<Name>
    local self = setmetatable({}, <Name>)
    -- Initialize injected refs to nil :: any
    return self
end

function <Name>:Init(registry: any, _name: string)
    -- self.SomeDependency = registry:Get("SomeDependency")
end

function <Name>:Execute(...: any): Result.Result<any>
    -- 1) Validate/guard inputs
    -- 2) Domain policy/service checks
    -- 3) Infrastructure mutation/persist/sync
    return Ok(table.freeze({}))
end

return <Name>
```

### ApplicationQuery

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable(
    {} :: {
        -- Infrastructure dependencies only
    },
    <Name>
))

function <Name>.new(): T<Name>
    local self = setmetatable({}, <Name>)
    return self
end

function <Name>:Init(registry: any, _name: string)
    -- self.SyncService = registry:Get("SomeSyncService")
end

function <Name>:Execute(...: any): Result.Result<any>
    -- Inline guard checks, then read-only infrastructure calls
    return Ok(table.freeze({}))
end

return <Name>
```

### DomainPolicy

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

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

local <Name> = {}
<Name>.__index = <Name>

export type T<Name> = typeof(setmetatable({}, <Name>))

function <Name>.new(): T<Name>
    local self = setmetatable({}, <Name>)
    return self
end

function <Name>:Execute(input: any): any
    -- Pure domain logic, no side effects, no framework deps
    return table.freeze({
        Input = input,
    })
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

return <Name>
```

## Wiring rules

- Register new modules in `<ContextName>Context.lua` using the correct category:
  - `ApplicationCommand` / `ApplicationQuery` -> `"Application"`
  - `DomainPolicy` / `DomainService` / `DomainSpecs` / `DomainValueObject` -> `"Domain"` only if it is a runtime service that needs registry init; specs and value objects usually are not registry-registered
  - `InfrastructureService` / `InfrastructurePersistence` / `InfrastructureECS` -> `"Infrastructure"`
- Queries must not depend on Domain modules.
- Commands may depend on Domain + Infrastructure.
- Domain services are pure and must not require Knit, JECS, ProfileStore, Charm, or Roblox instance APIs for side effects.
- Infrastructure is the only layer that mutates sync state.

## Rules

- Do not create `Application/Services/` (deprecated).
- All files start with `--!strict`.
- Reuse `Errors.lua` constants; do not add inline error strings.
- Use constructor + `Init(registry, _name)` pattern for registry-managed services.
- Keep context methods as pass-through bridges; no business logic in `'<ContextName>Context.lua'`.

