# AI.Runtime

Shared AI package module for running agnostic server-side AI loops while keeping bounded contexts authoritative over ECS state, tree definitions, executors, and domain-specific inputs.

## Purpose

- Keep generic AI frame orchestration shared across contexts.
- Reuse `AI.Behavior` for tree compilation and executor lifecycle dispatch.
- Let contexts declare hook modules for facts and service composition.
- Let contexts keep authoritative AI state in their own ECS or runtime storage.

## Ownership Split

`AiRuntime` owns:

- actor iteration
- hook execution and contribution merging
- behavior-tree evaluation gating
- pending-to-current action transitions
- current-action ticking
- finished-action resolution
- runtime defect routing through an optional error sink

The owning context still owns:

- behavior tree definitions
- action executor registrations
- authoritative action-state storage
- authoritative behavior-tree storage
- facts gathering logic inside hooks
- domain consequences after action success or failure

## Public Surface

```lua
local AiRuntime = require(ReplicatedStorage.Utilities.AI.Runtime)

local runtime = AiRuntime.new({
	Conditions = conditions,
	Commands = commands,
	Hooks = {
		FactsHook,
		ServicesHook,
	},
	ErrorSink = function(payload)
		warn(payload.Stage, payload.ActorType, payload.Entity, payload.ErrorMessage)
	end,
})

runtime:RegisterActions(executorDefinitions)
runtime:RegisterActorType("Enemy", enemyAdapter)

local tree = runtime:BuildTree(definition)
runtime:RunFrame({
	CurrentTime = os.clock(),
	DeltaTime = dt,
	Services = services,
})
```

Cleanup helpers:

```lua
runtime:HandleActorDeath("Enemy", entity, {
	CurrentTime = os.clock(),
	Services = services,
})

for _, enemyEntity in ipairs(enemyEntityFactory:QueryAliveEntities()) do
	runtime:CancelActorAction("Enemy", enemyEntity, {
		CurrentTime = os.clock(),
		Services = services,
	})
end
```

## Hook Contract

Hooks are ordered modules that expose:

```lua
Hook.Use(entity, hookContext) -> contributionTable?
```

Allowed contribution keys:

- `Facts`
- `BehaviorContext`
- `Services`

Merge rules:

- hooks run in registration order
- each bucket is shallow-merged in order
- later hooks override earlier keys on collision

Hooks should be read-only composition points. They should not mutate authoritative AI state directly.

## Actor Adapter Contract

Required methods:

- `QueryActiveEntities(frameContext) -> {number}`
- `GetBehaviorTree(entity) -> any?`
- `GetActionState(entity) -> any?`
- `SetActionState(entity, actionState) -> ()`
- `ClearActionState(entity) -> ()`
- `SetPendingAction(entity, actionId, actionData) -> ()`
- `UpdateLastTickTime(entity, currentTime) -> ()`
- `ShouldEvaluate(entity, currentTime) -> boolean`

Optional methods:

- `GetActorLabel() -> string?`

`SetPendingAction` is the adapter's write surface used by command nodes during tree evaluation. This keeps pending-action mutation inside the adapter boundary rather than inside the shared utility.

## Future Combat Mapping

- `CombatBehaviorRuntimeService` can become a thin wrapper around `AiRuntime`.
- The AI-specific phase logic in `ProcessCombatTick` can move into `runtime:RunFrame(...)`.
- Actor removal paths can move into `runtime:HandleActorDeath(...)`.
- Wave or run shutdown loops can call `runtime:CancelActorAction(...)` per actor.
- Combat-local node registries, hooks, executors, and entity adapters stay Combat-owned.

## Cleanup APIs

`AiRuntime` also exposes two explicit single-actor cleanup methods:

- `CancelActorAction(actorType, entity, frameContext)`
- `HandleActorDeath(actorType, entity, frameContext)`

These methods:

- resolve the registered adapter from `actorType`
- build the same merged runtime `Services` bag used by frame execution
- invoke the correct `BehaviorSystem` cleanup boundary
- clear action state through the adapter afterward
- emit defects through `ErrorSink` when executor cleanup fails

Batch shutdown remains caller-owned in v1. The caller is still responsible for broader teardown such as target clearing, constraint detach, hitbox cleanup, movement cleanup, and loop shutdown.
