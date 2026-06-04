# Behavior Tree Setup

Behavior trees are now feature-owned configuration that `AIContext` compiles and runs.

`AIContext` owns:

- evaluations
- actions
- fact providers
- behavior compilation
- scheduled decision execution

The owning feature context owns:

- behavior tree definitions
- profile records
- actor setup through `SetupEntityAIFromProfile`

## Current Split

Use this shape:

- `Contexts/<Feature>/Config/AIBehaviors.lua` for behavior tree definitions
- `Contexts/<Feature>/Config/AIProfiles.lua` for profile records
- `Contexts/AI/Config/Evaluations/*` for reusable evaluations
- `Contexts/AI/Config/Actions/*` for reusable actions
- `Contexts/AI/Config/Facts/*` for reusable fact providers

Behavior trees should compose generic leaves such as:

- `HasTargetEntity`
- `HasGoalTarget`
- `CanAttack`
- `Attack`
- `Advance`
- `ManualMove`
- `Idle`

## Behavior Tree Role

A behavior tree decides the next semantic action. It does not execute gameplay.

Current flow:

```text
feature facts
  -> behavior tree
  -> AI.ActionIntent
  -> shared action start
  -> actor state component
  -> shared domain systems
```

That means:

- the behavior tree selects intent
- `AIContext` validates and starts action state
- combat, movement, cleanup, and other domains execute through ECS systems

## Example

```lua
local EnemyAttackOrAdvance = table.freeze({
	Priority = {
		{
			Sequence = {
				"CanAttack",
				"Attack",
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

return table.freeze({
	EnemyAttackOrAdvance = {
		DefinitionId = "EnemyAttackOrAdvance",
		Tree = EnemyAttackOrAdvance,
	},
})
```

Profile example:

```lua
return table.freeze({
	EnemySwarmAI = {
		ProfileId = "EnemySwarmAI",
		DefinitionId = "EnemyAttackOrAdvance",
		TickInterval = 0.1,
	},
})
```

## Rules

- Put behavior trees in the owning feature context, not in `AIContext`.
- Keep leaves generic and reusable whenever possible.
- Do not put executor code, service callbacks, or gameplay mutation inside the tree definition.
- If an action needs multiple steps, let ECS systems advance actor state or emit request entities after intent is selected.

## Key Files

- [AIContext.lua](../Contexts/AI/AIContext.lua)
- [Enemy AI behavior config](../Contexts/Enemy/Config/AIBehaviors.lua)
- [Enemy AI profile config](../Contexts/Enemy/Config/AIProfiles.lua)
- [BasicEvaluations.lua](../Contexts/AI/Config/Evaluations/BasicEvaluations.lua)
- [BasicActions.lua](../Contexts/AI/Config/Actions/BasicActions.lua)
