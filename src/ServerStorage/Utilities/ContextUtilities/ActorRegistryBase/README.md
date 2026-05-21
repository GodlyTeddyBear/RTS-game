# ActorRegistryBase

Shared registry base for actor-type systems that need to register types, queue pending actors, create live runtime records, and query active runtime ids without owning context-specific behavior.

## What It Does

`ActorRegistryBase` owns the reusable registry mechanics for actor systems:

- stores registered actor types
- stores live actor records by runtime id and handle
- stores pending actor payloads that have not been committed yet
- prevents duplicate actor types and duplicate handles
- tracks whether the runtime has started
- exposes deterministic query helpers for actor types and pending payloads

The base does **not** own:

- payload-shape validation
- live record construction
- stored actor-type payload construction
- active/inactive decisions for records
- removal side effects for a derived registry

Those pieces stay in the subclass through the `_Validate*`, `_Build*`, `_IsRecordActive`, and `_InvokeRemovedCallback` hooks.

## Folder Layout

- `init.lua` - the shared base class
- `Errors.lua` - shared error constants for the base and its derived registries
- `Policies/ActorTypeMetadataPolicy.lua` - shared metadata validation for actor-type registration payloads
- `Specs/RuntimeBindingSpecs.lua` - shared specs used by the metadata policy when runtime binding requirements are declared

## How To Use It

`ActorRegistryBase` is meant to be inherited by a context-owned registry service.

Typical setup:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActorRegistryBase = require(ReplicatedStorage.Utilities.ActorRegistryBase)

local CombatActorRegistryService = {}
CombatActorRegistryService.__index = CombatActorRegistryService
setmetatable(CombatActorRegistryService, ActorRegistryBase)

function CombatActorRegistryService.new()
    local self = ActorRegistryBase.new()
    return setmetatable(self, CombatActorRegistryService)
end
```

Then implement the subclass hooks that the base expects:

- `_ValidateActorTypePayload(payload)`
- `_ValidateActorPayload(payload)`
- `_BuildStoredActorTypePayload(payload)`
- `_BuildRecordFromPayload(payload, runtimeId, buildContext?)`
- `_IsRecordActive(record)`
- `_InvokeRemovedCallback(record)` if the subclass needs removal cleanup

The Combat registry in `src/ServerScriptService/Contexts/Combat/Infrastructure/Services/CombatActorRegistryService.lua` follows this pattern.

## Registration Flow

Use the base methods in this order:

1. Call `RegisterActorType(payload)` to store a validated actor type.
2. Call `RegisterActor(payload, buildContext?)` to create a live record immediately.
3. Call `QueueActor(payload)` when the actor should be deferred until later.
4. Call `ConsumePendingActorPayloads()` when the registry should flush the queue in deterministic order.
5. Call `UnregisterActor(actorHandle)` or `DiscardActor(actorHandle)` when the actor leaves.

`RegisterActorType` must happen before actor registration for that type. `RegisterActor` and `QueueActor` both reject unknown actor types and duplicate handles.

## Common Queries

- `GetPendingActorPayloads()` returns pending payloads sorted by `ActorHandle`.
- `GetActorTypePayloads()` returns registered actor-type payloads sorted by `ActorType`.
- `GetActorTypePayload(actorType)` returns one stored actor-type payload.
- `GetRecord(runtimeId)` returns one live record by runtime id.
- `GetRecordByHandle(actorHandle)` returns one live record by handle.
- `QueryActiveRuntimeIds(actorType)` returns only the runtime ids whose records still satisfy `_IsRecordActive`.

## Runtime Rules

- Call `SetRuntimeStarted(true)` once the owning registry is live and no new actor types should be added.
- Call `SetRuntimeStarted(false)` only when the registry is being reset or torn down.
- Use `ClearAll()` to reset every internal index and restart the runtime id counter.

## Example

```lua
local ActorRegistryBase = require(ReplicatedStorage.Utilities.ActorRegistryBase)

local CombatActorRegistryService = {}
CombatActorRegistryService.__index = CombatActorRegistryService
setmetatable(CombatActorRegistryService, ActorRegistryBase)

function CombatActorRegistryService.new()
    local self = ActorRegistryBase.new()
    return setmetatable(self, CombatActorRegistryService)
end

function CombatActorRegistryService:_ValidateActorTypePayload(payload)
    -- validate the combat-specific type payload
end

function CombatActorRegistryService:_ValidateActorPayload(payload)
    -- validate the combat-specific actor payload
end

function CombatActorRegistryService:_BuildStoredActorTypePayload(payload)
    -- store the combat-specific type payload shape
end

function CombatActorRegistryService:_BuildRecordFromPayload(payload, runtimeId, buildContext)
    -- build the combat-specific runtime record
end

function CombatActorRegistryService:_IsRecordActive(record)
    -- report whether this actor should be counted as active
end
```

## Notes

- `Errors.lua` is the shared source of error strings for the base and derived registries.
- `ActorTypeMetadataPolicy` is used by the base before an actor type is committed to the registry.
- `RuntimeBindingSpecs` supports runtime-binding validation when an actor type declares polling or projection requirements.
- The base is a technical utility, not a context owner and not a gameplay service.
