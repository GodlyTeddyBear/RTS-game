# BehaviorSystem

Shared utility for validating symbolic behavior definitions and compiling them into concrete `BehaviorTree` instances.

## Purpose

- Keep behavior-definition validation and compilation shared across contexts.
- Keep condition and command registries outside individual feature modules.
- Leave runtime facts, action requests, and execution orchestration to the owning context.

## Public Surface

Exports:

- `Builder`
- `Validator`
- `Types`
- `Helpers`

Builder methods:

- `Builder.new(config)` creates a builder from `Conditions` and `Commands` registries.
- `Builder:Validate(definition)` validates a symbolic behavior definition against the configured registries.
- `Builder:Build(definition)` validates and compiles the definition into a `BehaviorTree`.

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

## Runtime Boundary

`BehaviorSystem` owns validation, definition compilation, and tree construction.

The owning context still owns:

- facts gathering
- action request shape
- runtime side effects
- executor orchestration
