# Action System Setup

This document explains how to add a client action for the animation action system used by the player and NPC controllers.

The action system owns:

- animation-state to action lookup
- keyframe marker dispatch
- optional SFX/VFX dispatch
- optional server callback dispatch from animation markers

The owning controller still owns:

- model tracking
- action registration
- the action context bag
- cleanup when the model disappears

## File Split

Use the same pattern as the existing enemy and structure controllers:

- `Actions/` for action subclasses
- `EnemyAnimationController.lua` or `StructureAnimationController.lua` for registration
- `ActionRegistry.Register(...)` for mapping animation states to action instances

## 1. Create The Action Class

An action class should inherit from `BaseAction`.

The important fields are:

- `AnimationKey` to match the model's `AnimationState` attribute
- `Looped` to match the animation behavior
- `Events` to map marker names to SFX, VFX, or server callbacks

Example:

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)

local AttackAction = {}
AttackAction.__index = AttackAction
setmetatable(AttackAction, BaseAction)

AttackAction.AnimationKey = "AttackStructure"
AttackAction.Looped = false

AttackAction.Events = {
	Strike = { ServerCallback = "ActivateHitbox" },
}

function AttackAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, AttackAction)
end

return AttackAction
```

## 2. Add Custom Marker Logic When Needed

`BaseAction` already handles table-driven marker effects. If you need extra logic on a marker, add `OnCustomEvent`.

Example:

```lua
function AttackAction:OnCustomEvent(name: string, context: any)
	if name == "Strike" then
		self:_RequestServerCallback("ActivateHitbox", context)
	end
end
```

Use `OnCustomEvent` only when the table-driven `Events` map is not enough.

## 3. Register The Action In The Controller

The controller should create the action instance in `KnitInit()` and register it with `ActionRegistry`.

Example:

```lua
local attackAction = AttackAction.new()
ActionRegistry.Register("AttackStructure", attackAction)
ActionRegistry.Register("AttackBase", attackAction)
```

Rules:

- Register the action under the exact animation state string used by the model.
- If multiple animation states use the same behavior, register the same action instance under each state.
- Register before the animation driver starts tracking models.

## 4. Build The Action Context

The controller passes a context bag to `AnimateEnemyModule.setup(...)` or `AnimateStructureModule.setup(...)`.

The action context should provide only what the action needs:

- `Model`
- `CombatService` when server callbacks are needed
- `ActorKind`
- `ActorId` or `NPCId`
- `ResolveTargetInstance` when the action needs target-space VFX

For enemy actors, the controller should return the canonical actor handle shape:

- `Enemy:<EnemyId>`

For structure actors, the controller should return the canonical structure handle shape:

- `Structure:<StructureId>`
- or `Structure:<PlacementInstanceId>`

## 5. Typical Build Order

1. Create the action subclass in `Actions/`.
2. Set `AnimationKey`, `Looped`, and `Events`.
3. Register the action in the matching animation controller.
4. Make sure the model publishes the matching `AnimationState` attribute.
5. Add the animation marker or server callback flow the action needs.

## Practical Rule

If the animation state changes, register a new action key.
If the marker only plays effects, use `Events`.
If the marker needs game logic, route it through a server callback or `OnCustomEvent`.

## Key Files

- [BaseAction.lua](../../ReplicatedStorage/Utilities/ActionSystem/BaseAction.lua)
- [ActionRegistry.lua](../../ReplicatedStorage/Utilities/ActionSystem/ActionRegistry.lua)
- [Types.lua](../../ReplicatedStorage/Utilities/ActionSystem/Types.lua)
- [EnemyAnimationController.lua](../../StarterPlayerScripts/Contexts/Enemy/EnemyAnimationController.lua)
- [StructureAnimationController.lua](../../StarterPlayerScripts/Contexts/Structure/StructureAnimationController.lua)
- [AttackAction.lua](../../StarterPlayerScripts/Contexts/Enemy/Actions/AttackAction.lua)
- [StructureAttackAction.lua](../../StarterPlayerScripts/Contexts/Structure/Actions/StructureAttackAction.lua)
