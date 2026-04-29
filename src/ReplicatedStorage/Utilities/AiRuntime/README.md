# AiRuntime

Shared utility for running agnostic server-side AI loops while keeping bounded contexts authoritative over ECS state, tree definitions, executors, and domain-specific inputs.

## Purpose

- Keep generic AI frame orchestration shared across contexts.
- Reuse `BehaviorSystem` for tree compilation and executor lifecycle dispatch.
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
local AiRuntime = require(ReplicatedStorage.Utilities.AiRuntime)

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
- Combat-local node registries, hooks, executors, and entity adapters stay Combat-owned.
