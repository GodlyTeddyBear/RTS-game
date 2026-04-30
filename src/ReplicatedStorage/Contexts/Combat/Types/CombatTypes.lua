--!strict

--[=[
	@class CombatTypes
	Defines shared combat runtime shapes used by the combat context.
	@server
	@client
]=]
local CombatTypes = {}

--[=[
	@interface CombatSession
	@within CombatTypes
	Active combat session metadata keyed by user id.
	.WaveNumber number -- Current wave number for the active session.
	.IsEndless boolean -- Whether the current run is endless.
	.IsPaused boolean -- Whether combat updates are paused.
]=]
export type CombatSession = {
	WaveNumber: number,
	IsEndless: boolean,
	IsPaused: boolean,
}

--[=[
	@interface GoalResolution
	@within CombatTypes
	Resolved data describing an enemy that reached the goal.
	.enemyEntity number -- Entity id that reached the goal.
	.role string -- Enemy role used for damage tuning.
	.waveNumber number -- Wave number associated with the enemy.
	.deathCFrame CFrame -- CFrame captured before despawn.
	.damage number -- Commander damage to apply.
]=]
export type GoalResolution = {
	enemyEntity: number,
	role: string,
	waveNumber: number,
	deathCFrame: CFrame,
	damage: number,
}

--[=[
	@interface CombatActorTypePayload
	@within CombatTypes
	Actor-type catalog sent by an owning context before Combat starts its generic runtime.
	.ActorType string -- Stable actor-type key, for example `Enemy` or `Structure`.
	.Conditions table -- Behavior-tree condition node builders for this actor type.
	.Commands table -- Behavior-tree command node builders for this actor type.
	.Executors table -- Action executor definitions keyed by action id.
	.Hooks table? -- Optional additional AI hooks contributed by the actor context.
]=]
export type CombatActorTypePayload = {
	ActorType: string,
	Conditions: { [string]: (any?) -> any },
	Commands: { [string]: (any?) -> any },
	Executors: { [string]: any },
	Hooks: { any }?,
}

--[=[
	@interface CombatActorAdapter
	@within CombatTypes
	Owning-context callback surface used by Combat's generic runtime.
	.IsActive function -- Returns whether the owning context still considers the actor active.
	.GetActorLabel function? -- Optional diagnostic label for runtime defects.
	.BuildFacts function -- Builds behavior-tree facts for one Combat-owned runtime actor.
	.BuildServices function -- Builds executor services for one Combat-owned runtime actor.
	.OnCancel function? -- Optional cleanup callback when Combat cancels an active action.
	.OnRemoved function? -- Optional cleanup callback when Combat unregisters the actor.
]=]
export type CombatActorAdapter = {
	IsActive: () -> boolean,
	GetActorLabel: (() -> string?)?,
	BuildFacts: (currentTime: number) -> { [string]: any },
	BuildServices: (currentTime: number) -> { [string]: any },
	OnCancel: (() -> ())?,
	OnRemoved: (() -> ())?,
}

--[=[
	@interface CombatActorPayload
	@within CombatTypes
	Combat-capable actor registration payload sent after the owning context creates the entity.
	.ActorType string -- Previously registered actor-type key.
	.ActorHandle string -- Opaque stable handle owned by the sender, not a foreign ECS id.
	.BehaviorDefinition any -- Symbolic behavior definition compiled and owned by Combat.
	.TickInterval number -- Minimum seconds between behavior-tree evaluations.
	.Adapter CombatActorAdapter -- Owning-context callback surface.
]=]
export type CombatActorPayload = {
	ActorType: string,
	ActorHandle: string,
	BehaviorDefinition: any,
	TickInterval: number,
	Adapter: CombatActorAdapter,
}

export type CombatActionState = {
	CurrentActionId: string?,
	ActionState: string,
	ActionData: any?,
	PendingActionId: string?,
	PendingActionData: any?,
	StartedAt: number?,
	FinishedAt: number?,
}

export type CombatActorRecord = {
	RuntimeId: number,
	ActorType: string,
	ActorHandle: string,
	BehaviorTree: any,
	TickInterval: number,
	LastTickTime: number,
	ActionState: CombatActionState,
	Adapter: CombatActorAdapter,
}

return table.freeze(CombatTypes)
