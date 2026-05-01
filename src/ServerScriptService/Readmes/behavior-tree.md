# Behavior Tree Setup

This document shows the standard way to build a behavior tree in this repo and split it into:

- the behavior definition
- condition builders
- command builders
- executor modules

The shared AI package owns tree compilation and executor dispatch. The context still owns facts, pending action state, and the actual executor implementations.

## File Split

Use the same layout as the combat, enemy, unit, and structure behavior systems:

- `Behaviors/` for symbolic tree definitions
- `Nodes/Conditions.lua` for condition builders
- `Nodes/Commands.lua` for command builders
- `Executors/` for action executor modules
- `Executors/init.lua` for action registration

## 1. Create The Behavior Tree

A behavior tree file should only describe the symbolic tree shape. It should not run logic directly.

Supported composite nodes:

- `Priority`
- `Sequence`

Leaf nodes are string keys that resolve against the condition and command registries.

Example:

```lua
--!strict

local TankBehavior = table.freeze({
	Priority = {
		{
			Sequence = {
				"HasStructureTargetInRange",
				"AttackStructure",
			},
		},
		{
			Sequence = {
				"HasBaseTargetInRange",
				"AttackBase",
			},
		},
		{
			Sequence = {
				"HasGoalTarget",
				"Advance",
			},
		},
		"Idle",
	},
})

return TankBehavior
```

Rules to keep in mind:

- `Sequence` evaluates children left to right.
- `Priority` evaluates children until one succeeds.
- A leaf string must exist in exactly one registry.
- Composite nodes should always use non-empty child arrays.

## 2. Create Condition Builders

Conditions are builder functions that return a condition task.

The usual pattern is:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Conditions = {
	HasGoalTarget = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			if context.Facts.HasGoalTarget then
				task:success()
				return
			end

			task:fail()
		end)
	end,
}

return table.freeze(Conditions)
```

Condition rules:

- Each key is the symbol name used in the tree.
- Each builder returns `BehaviorSystem.Helpers.CreateConditionTask(...)`.
- The task should call `task:success()` or `task:fail()`.
- Conditions should read facts only.

## 3. Create Command Builders

Commands are builder functions that return a command task.

Commands are where the tree requests an action change. They should set pending action state through the context-owned action factory or equivalent adapter surface.

Example:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local function _requireActionFactory(context)
	local actionFactory = context.ActionFactory
	assert(
		type(actionFactory) == "table" and type(actionFactory.SetPendingAction) == "function",
		"Behavior command nodes require context.ActionFactory:SetPendingAction"
	)
	return actionFactory
end

local Commands = {
	Advance = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _requireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "Advance", nil)
			task:success()
		end)
	end,
}

return table.freeze(Commands)
```

Command rules:

- Each key is the action symbol used in the tree.
- Each builder returns `BehaviorSystem.Helpers.CreateCommandTask(...)`.
- Commands should stay thin and only request the next action.
- The command should not own the authoritative action lifecycle itself.

## 4. Create Executors

Each action needs an executor module that exposes `.new` and usually inherits from `BaseExecutor`.

The shared runtime calls the executor boundary, which in turn maps to the base lifecycle:

- `BaseExecutor.new(config)`
- `CanStart(entity, data, services)`
- `OnStart(entity, data, services)`
- `CanContinue(entity, services)`
- `OnTick(entity, dt, services)`
- `OnCancel(entity, services)`
- `OnComplete(entity, services)`
- `OnDeath(entity, services)`

Example executor:

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

local AttackBaseExecutor = {}
AttackBaseExecutor.__index = AttackBaseExecutor
setmetatable(AttackBaseExecutor, BaseExecutor)

function AttackBaseExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "AttackBase",
		IsCommitted = false,
	})
	return setmetatable(self, AttackBaseExecutor)
end

function AttackBaseExecutor:CanStart(_entity, data, services)
	if type(data) ~= "table" then
		return false, "MissingActionData"
	end

	if services.CombatPerceptionService == nil then
		return false, "MissingCombatPerceptionService"
	end

	return true, nil
end

function AttackBaseExecutor:OnStart(entity, data, services)
	services.StructureEntityFactory:SetTarget(entity, data.TargetEnemyEntity)
	self:SetEntityValue(entity, "StartedAt", services.CurrentTime)
end

function AttackBaseExecutor:OnTick(entity, _dt, services)
	local startedAt = self:GetEntityValue(entity, "StartedAt")
	if type(startedAt) ~= "number" then
		return self:Fail(entity, "MissingStartTime")
	end

	if services.CurrentTime - startedAt < 0.5 then
		return self:Running()
	end

	return self:Success()
end

function AttackBaseExecutor:OnCancel(entity, services)
	self:ClearEntityValue(entity, "StartedAt")
	services.StructureEntityFactory:SetTarget(entity, nil)
end

function AttackBaseExecutor:OnComplete(entity, services)
	self:ClearEntityValue(entity, "StartedAt")
	services.StructureEntityFactory:SetTarget(entity, nil)
end

function AttackBaseExecutor:OnDeath(entity, services)
	self:ClearEntityValue(entity, "StartedAt")
	services.StructureEntityFactory:SetTarget(entity, nil)
end

return AttackBaseExecutor
```

Executor rules:

- Keep executor state inside the executor instance.
- Use the service bag passed by the runtime.
- Return status strings from `OnTick` through `self:Running()`, `self:Success()`, or `self:Fail(...)`.
- Keep side effects inside the owning context services you were given.
- Set `ActionId` to the action id that the behavior tree command queues.

## 5. Register Executors

If you use folder discovery, `Executors/init.lua` should collect action modules and return a table of action definitions.

The common pattern is:

- module name ends with `Executor`
- module exports `.new`
- the action id is derived from the module name

Example:

```lua
local AttackBaseExecutor = require(script.Parent.AttackBaseExecutor)

local Executors = table.freeze({
	AttackBase = {
		ActionId = "AttackBase",
		CreateExecutor = AttackBaseExecutor.new,
	},
})

return Executors
```

## 6. Typical Build Order

1. Add the behavior symbol file under `Behaviors/`.
2. Add condition builders under `Nodes/Conditions.lua`.
3. Add command builders under `Nodes/Commands.lua`.
4. Add executor modules under `Executors/`.
5. Register the executors in `Executors/init.lua`.
6. Pass the registries into `AI.GetBehaviorSystem()` or the context-specific AI setup.

## Practical Rule

If a node needs facts, make it a condition.
If a node needs to queue an action, make it a command.
If a node needs to run over multiple frames, make it an executor.
