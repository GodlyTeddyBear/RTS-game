# AI.AdapterFactory

Shared AI package module for building `AI.Runtime` actor adapters from explicit callbacks.

## Purpose

- Remove repetitive adapter glue when multiple contexts need `AI.Runtime`.
- Keep adapter construction explicit and context-owned.
- Avoid pushing ECS, behavior-tree, or domain ownership into `AI.Runtime` itself.

## Required Config

`AI.AdapterFactory.Create(config)` requires a callback bundle with these fields:

- `QueryActiveEntities(frameContext)`
- `GetCompiledBehaviorTree(entity)`
- `GetActionState(entity)`
- `SetActionState(entity, actionState)`
- `ClearActionState(entity)`
- `SetPendingAction(entity, actionId, actionData)`
- `UpdateLastTickTime(entity, currentTime)`
- `ShouldEvaluate(entity, currentTime)`

`ActorLabel` is optional. When present, it must be a non-empty string and is returned through `GetActorLabel()`.

`GetActionState` must return either a table or `nil`, and the returned action-state table must only use the supported `TActionState` shape.

## Factory Surface

`AI.AdapterFactory.CreateFactory(config)` supports the same adapter contract, but resolves each callback from method-name strings or direct functions on a caller-owned factory object.

Use it when the context wants to keep the adapter surface explicit while reducing repeated method wiring.

## Boundaries

`AI.AdapterFactory` owns:

- validating adapter-builder config
- eagerly resolving factory-backed method-name surfaces during construction
- producing a plain adapter table that matches the `AiRuntime` adapter contract
- forwarding adapter calls into caller-provided callbacks
- asserting shared action-state shape at the adapter boundary

The owning context still owns:

- entity factories and ECS state
- behavior-tree storage
- action-state storage
- pending-action mutation semantics
- tick-evaluation rules
- all domain-specific AI logic

The factory does not invent defaults for missing required callbacks. If one of the required surfaces cannot be resolved, adapter creation fails.

## Public Surface

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AiAdapterFactory = require(ReplicatedStorage.Utilities.AI.AdapterFactory)

local enemyAdapter = AiAdapterFactory.Create({
	ActorLabel = "Enemy",
	QueryActiveEntities = function(frameContext)
		return enemyEntityFactory:QueryAliveEntities()
	end,
	GetCompiledBehaviorTree = function(entity)
		return enemyEntityFactory:GetBehaviorTree(entity)
	end,
	GetActionState = function(entity)
		return enemyEntityFactory:GetCombatAction(entity)
	end,
	SetActionState = function(entity, actionState)
		enemyEntityFactory:SetCombatAction(entity, actionState)
	end,
	ClearActionState = function(entity)
		enemyEntityFactory:ClearAction(entity)
	end,
	SetPendingAction = function(entity, actionId, actionData)
		enemyEntityFactory:SetPendingAction(entity, actionId, actionData)
	end,
	UpdateLastTickTime = function(entity, currentTime)
		enemyEntityFactory:UpdateBTLastTickTime(entity, currentTime)
	end,
	ShouldEvaluate = function(entity, currentTime)
		local compiledTree = enemyEntityFactory:GetBehaviorTree(entity)
		if compiledTree == nil then
			return false
		end

		local tickState = enemyTickStateByEntity[entity]
		if tickState == nil then
			return false
		end

		return currentTime - tickState.LastTickTime >= tickState.TickInterval
	end,
})
```

Then register the built adapter with `AiRuntime`:

```lua
runtime:RegisterActorType("Enemy", enemyAdapter)
```

## Combat Example

Enemy adapter:

```lua
local enemyAdapter = AiAdapterFactory.Create({
	ActorLabel = "Enemy",
	QueryActiveEntities = function(_frameContext)
		return enemyEntityFactory:QueryAliveEntities()
	end,
	GetCompiledBehaviorTree = function(entity)
		return enemyEntityFactory:GetBehaviorTree(entity)
	end,
	GetActionState = function(entity)
		return enemyEntityFactory:GetCombatAction(entity)
	end,
	SetActionState = function(entity, actionState)
		enemyEntityFactory:SetCombatAction(entity, actionState)
	end,
	ClearActionState = function(entity)
		enemyEntityFactory:ClearAction(entity)
	end,
	SetPendingAction = function(entity, actionId, actionData)
		enemyEntityFactory:SetPendingAction(entity, actionId, actionData)
	end,
	UpdateLastTickTime = function(entity, currentTime)
		enemyEntityFactory:UpdateBTLastTickTime(entity, currentTime)
	end,
	ShouldEvaluate = function(entity, currentTime)
		local compiledTree = enemyEntityFactory:GetBehaviorTree(entity)
		if compiledTree == nil then
			return false
		end

		local tickState = enemyTickStateByEntity[entity]
		if tickState == nil then
			return false
		end

		return currentTime - tickState.LastTickTime >= tickState.TickInterval
	end,
})
```

Structure adapter:

```lua
local structureAdapter = AiAdapterFactory.Create({
	ActorLabel = "Structure",
	QueryActiveEntities = function(_frameContext)
		return structureEntityFactory:QueryActiveEntities()
	end,
	GetCompiledBehaviorTree = function(entity)
		return structureEntityFactory:GetBehaviorTree(entity)
	end,
	GetActionState = function(entity)
		return structureEntityFactory:GetCombatAction(entity)
	end,
	SetActionState = function(entity, actionState)
		structureEntityFactory:SetCombatAction(entity, actionState)
	end,
	ClearActionState = function(entity)
		structureEntityFactory:ClearAction(entity)
	end,
	SetPendingAction = function(entity, actionId, actionData)
		structureEntityFactory:SetPendingAction(entity, actionId, actionData)
	end,
	UpdateLastTickTime = function(entity, currentTime)
		structureEntityFactory:UpdateBTLastTickTime(entity, currentTime)
	end,
	ShouldEvaluate = function(entity, currentTime)
		local compiledTree = structureEntityFactory:GetBehaviorTree(entity)
		if compiledTree == nil then
			return false
		end

		local tickState = structureTickStateByEntity[entity]
		if tickState == nil then
			return false
		end

		return currentTime - tickState.LastTickTime >= tickState.TickInterval
	end,
})
```

## Design Notes

- The utility does not inspect JECS or behavior-tree payloads itself.
- The utility does not assume method names on entity factories.
- `ShouldEvaluate` and `UpdateLastTickTime` stay fully caller-owned in v1, including tick interval and last-tick persistence.
- This is a bridge-builder, not a base class and not a lifecycle owner.
- `CreateFactory` is for factory-backed method resolution only; it does not change the adapter contract.
