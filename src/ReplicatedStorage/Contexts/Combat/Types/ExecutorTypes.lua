--!strict

--[=[
	@class ExecutorTypes
	Defines shared combat executor component and service shapes.
	@server
	@client
]=]

--[=[
	@interface TBehaviorTreeComponent
	@within ExecutorTypes
	Stores the assigned behavior tree and tick state for an enemy.
	.TreeInstance any -- Behavior tree object assigned to the enemy.
	.TickInterval number -- Minimum time between behavior tree evaluations.
	.LastTickTime number -- Timestamp of the last successful tick.
]=]
export type TBehaviorTreeComponent = {
	TreeInstance: any,
	TickInterval: number,
	LastTickTime: number,
}

--[=[
	@type TCombatActionState
	@within ExecutorTypes
	Current execution state for a combat action component.
]=]
export type TCombatActionState = "Idle" | "Running" | "Committed"

--[=[
	@interface TCombatActionComponent
	@within ExecutorTypes
	Tracks the current and pending action ids for one enemy.
	.CurrentActionId string? -- Action currently being executed.
	.ActionState TCombatActionState -- Current state of the action lifecycle.
	.ActionData any? -- Data attached to the current action.
	.PendingActionId string? -- Action queued by behavior tree evaluation.
	.PendingActionData any? -- Data attached to the pending action.
	.StartedAt number? -- Timestamp when the current action started.
	.FinishedAt number? -- Timestamp when the current action most recently resolved.
]=]
export type TCombatActionComponent = {
	CurrentActionId: string?,
	ActionState: TCombatActionState,
	ActionData: any?,
	PendingActionId: string?,
	PendingActionData: any?,
	StartedAt: number?,
	FinishedAt: number?,
}

--[=[
	@interface TAttackCooldownComponent
	@within ExecutorTypes
	Stores a future attack cooldown window for enemy action systems.
	.Cooldown number -- Minimum time between attacks.
	.LastAttackTime number -- Timestamp of the last attack.
]=]
export type TAttackCooldownComponent = {
	Cooldown: number,
	LastAttackTime: number,
}

--[=[
	@interface TBehaviorConfigComponent
	@within ExecutorTypes
	Stores role-specific behavior tree timing for one enemy.
	.TickInterval number -- Role-specific time between behavior tree evaluations.
]=]
export type TBehaviorConfigComponent = {
	TickInterval: number,
}

--[=[
	@interface TExecutorServices
	@within ExecutorTypes
	Shared runtime services passed into combat executors.
	.EnemyEntityFactory any -- Combat enemy entity access facade.
	.StructureEntityFactory any -- Combat structure entity access facade.
	.EnemyContext any -- Enemy context public damage API.
	.StructureContext any -- Structure context public damage API.
	.CurrentTime number -- Timestamp shared across executor calls for one tick.
	.HandleGoalReached any -- Command used to resolve goal-reaching enemies.
	.HitboxService any -- Combat hitbox service for contact-confirmed attacks.
]=]
export type TExecutorServices = {
	EnemyEntityFactory: any,
	StructureEntityFactory: any,
	EnemyContext: any,
	StructureContext: any,
	CurrentTime: number,
	HandleGoalReached: any,
	HitboxService: any,
}

return table.freeze({})
