# AI.AdapterFactory

Shared AI package module for building `AI.Runtime` actor adapters from explicit callbacks.

## Purpose

- Remove repetitive adapter glue when multiple contexts need `AI.Runtime`.
- Keep adapter construction explicit and context-owned.
- Avoid pushing ECS, behavior-tree, or domain ownership into `AI.Runtime` itself.

## Boundaries

`AI.AdapterFactory` owns:

- validating adapter-builder config
- producing a plain adapter table that matches the `AiRuntime` adapter contract
- forwarding adapter calls into caller-provided callbacks

The owning context still owns:

- entity factories and ECS state
- behavior-tree storage
- action-state storage
- pending-action mutation semantics
- tick-evaluation rules
- all domain-specific AI logic

## Public Surface

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AiAdapterFactory = require(ReplicatedStorage.Utilities.AI.AdapterFactory)

local enemyAdapter = AiAdapterFactory.Create({
	ActorLabel = "Enemy",
	QueryActiveEntities = function(frameContext)
		return enemyEntityFactory:QueryAliveEntities()
	end,
	GetBehaviorTree = function(entity)
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
		local tree = enemyEntityFactory:GetBehaviorTree(entity)
		if tree == nil then
			return false
		end

		return currentTime - tree.LastTickTime >= tree.TickInterval
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
	GetBehaviorTree = function(entity)
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
		local tree = enemyEntityFactory:GetBehaviorTree(entity)
		if tree == nil then
			return false
		end

		return currentTime - tree.LastTickTime >= tree.TickInterval
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
	GetBehaviorTree = function(entity)
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
		local tree = structureEntityFactory:GetBehaviorTree(entity)
		if tree == nil then
			return false
		end

		return currentTime - tree.LastTickTime >= tree.TickInterval
	end,
})
```

## Design Notes

- The utility does not inspect JECS or behavior-tree payloads itself.
- The utility does not assume method names on entity factories.
- `ShouldEvaluate` stays fully caller-owned in v1.
- This is a bridge-builder, not a base class and not a lifecycle owner.
