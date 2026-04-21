--!strict

--[=[
	@class ExecutorTypes
	Defines shared combat executor component and service shapes.
]=]

--[=[
	@type TBehaviorTreeComponent
	@within ExecutorTypes
	Stores the assigned behavior tree and tick state for an enemy.
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
export type TCombatActionState = "None" | "Running" | "Committed"

--[=[
	@type TCombatActionComponent
	@within ExecutorTypes
	Tracks the current and pending action ids for one enemy.
]=]
export type TCombatActionComponent = {
	CurrentActionId: string?,
	ActionState: TCombatActionState,
	ActionData: any?,
	PendingActionId: string?,
	PendingActionData: any?,
	ActionStartedAt: number?,
}

--[=[
	@type TAttackCooldownComponent
	@within ExecutorTypes
	Stores a future attack cooldown window for enemy action systems.
]=]
export type TAttackCooldownComponent = {
	Cooldown: number,
	LastAttackTime: number,
}

--[=[
	@type TBehaviorConfigComponent
	@within ExecutorTypes
	Stores role-specific behavior tree timing for one enemy.
]=]
export type TBehaviorConfigComponent = {
	TickInterval: number,
}

--[=[
	@type TExecutorServices
	@within ExecutorTypes
	Shared runtime services passed into combat executors.
]=]
export type TExecutorServices = {
	EnemyEntityFactory: any,
	CurrentTime: number,
	HandleGoalReached: any,
}

return table.freeze({})
