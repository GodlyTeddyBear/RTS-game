# BehaviorSystem

Shared utility for validating symbolic behavior definitions and compiling them into concrete `BehaviorTree` instances.

## Purpose

- Keep behavior-definition validation and compilation shared across contexts.
- Keep condition and command registries outside individual feature modules.
- Leave runtime facts, action requests, and execution orchestration to the owning context.

## Public Surface

Exports:

- `Builder`
- `Runtime`
- `Validator`
- `Types`
- `Helpers`
- `new(config)` convenience constructor for the runtime facade

Builder methods:

- `Builder.new(config)` creates a builder from `Conditions` and `Commands` registries.
- `Builder:Validate(definition)` validates a symbolic behavior definition against the configured registries.
- `Builder:Build(definition)` validates and compiles the definition into a `BehaviorTree`.

Runtime methods:

- `BehaviorSystem.new(config)` creates a runtime facade with a configured builder.
- `runtime:Validate(definition)` validates against the configured registries.
- `runtime:BuildTree(definition)` builds a `BehaviorTree`.
- `runtime:RegisterAction(definition)` registers one action definition and executor.
- `runtime:RegisterActions(definitions)` registers many action definitions.
- `runtime:GetExecutor(actionId)` returns the registered executor instance for an action id.
- `runtime:StartPendingAction(entity, actionState, runtimeContext)` starts a pending action generically.
- `runtime:CommitStartedAction(actionState, startResult, startedAt?)` commits a started pending action into current action state.
- `runtime:TickCurrentAction(entity, actionState, runtimeContext)` ticks the current action generically.
- `runtime:ResolveFinishedAction(actionState, tickResult, finishedAt?)` resolves a terminal tick result back into idle action state.
- `runtime:OnActionSucceeded(tickResult, actionId?, callback)` runs a callback for successful actions, optionally filtered by action id.
- `runtime:CancelCurrentAction(entity, actionState, runtimeContext)` cancels the current action generically.

Validator methods:

- `ValidateRegistries(registries)` validates the registry bundle before compilation begins.
- `ValidateDefinition(definition, registries)` validates a symbolic tree against a registry bundle.

Helper constructors:

- `CreateTask(config)`
- `CreateConditionTask(run)`
- `CreateCommandTask(run)`
- `CreateSequence(nodes)`
- `CreatePriority(nodes)`

Helper predicates:

- `IsLeafNode(node)`
- `IsSequenceNode(node)`
- `IsPriorityNode(node)`
- `HasCondition(registry, name)`
- `HasCommand(registry, name)`

Types:

- `TConditionBuilder`
- `TCommandBuilder`
- `TConditionRegistry`
- `TCommandRegistry`
- `TBuilderConfig`
- `TBehaviorSequenceNode`
- `TBehaviorPriorityNode`
- `TBehaviorDefinitionNode`
- `TExecutor`
- `TActionRuntimeContext`
- `TActionDefinition`
- `TActionState`
- `TStartActionResult`
- `TCommitStartResult`
- `TTickActionResult`
- `TResolveFinishedActionResult`
- `TCancelActionResult`

## Definition Rules

- Leaf strings must resolve against exactly one registry.
- `Priority` and `Sequence` are the supported composite nodes in v1.
- Composite nodes must contain non-empty child arrays.
- Registry keys must be non-empty strings.
- Registry values must be builder functions.
- A symbol cannot exist in both registries.

## Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.BehaviorSystem)

local conditions = {
	HasWaypoints = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, ctx)
			if ctx.Facts.HasWaypoints then
				task:success()
				return
			end

			task:fail()
		end)
	end,
}

local commands = {
	Advance = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, ctx)
			ctx.PendingAction = "Advance"
			task:success()
		end)
	end,
}

local builder = BehaviorSystem.Builder.new({
	Conditions = conditions,
	Commands = commands,
})

local definition = {
	Priority = {
		{ Sequence = { "HasWaypoints", "Advance" } },
		"Advance",
	},
}

local tree = builder:Build(definition)
tree:run({
	Facts = {
		HasWaypoints = true,
	},
	PendingAction = nil,
})
```

## Runtime Dispatch Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.BehaviorSystem)

local conditions = {
	HasTarget = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, ctx)
			if ctx.Facts.HasTarget then
				task:success()
			else
				task:fail()
			end
		end)
	end,
}

local commands = {
	Attack = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, ctx)
			ctx.ActionState.PendingActionId = "Attack"
			ctx.ActionState.PendingActionData = {
				TargetId = ctx.Facts.TargetId,
			}
			task:success()
		end)
	end,
}

local runtime = BehaviorSystem.new({
	Conditions = conditions,
	Commands = commands,
})

runtime:RegisterAction({
	ActionId = "Attack",
	CreateExecutor = function()
		return {
			Start = function(_self, _entity, _data, _services)
				return true, nil
			end,
			Tick = function(_self, _entity, _dt, _services)
				return "Success"
			end,
			Cancel = function(_self, _entity, _services) end,
			Complete = function(_self, _entity, _services) end,
		}
	end,
})

local actionState = {
	PendingActionId = "Attack",
	PendingActionData = { TargetId = 5 },
	CurrentActionId = nil,
	ActionData = nil,
	ActionState = "Idle",
}

local startResult = runtime:StartPendingAction(123, actionState, {
	Services = {
		CombatService = {},
	},
})

runtime:CommitStartedAction(actionState, startResult, os.clock())

local tickResult = runtime:TickCurrentAction(123, actionState, {
	DeltaTime = 0.1,
	Services = {
		CombatService = {},
	},
})

runtime:OnActionSucceeded(tickResult, "Attack", function(_result)
	print("Attack finished successfully")
end)

runtime:ResolveFinishedAction(actionState, tickResult, os.clock())
```

## Runtime Boundary

`BehaviorSystem` owns:

- validation
- definition compilation
- tree construction
- action registration
- generic executor dispatch

The owning context still owns:

- facts gathering
- action-state storage
- action request shape
- runtime side effects
- post-action consequences

`BehaviorSystem` can perform the generic pending-to-current action-state transition through `CommitStartedAction(...)`, but the owning context still owns the action-state table itself and all domain-specific consequences.
