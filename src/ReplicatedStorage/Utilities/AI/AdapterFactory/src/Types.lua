--!strict

--[=[
	@class AiAdapterFactoryTypes
	Shared type definitions for `AiAdapterFactory` configuration and returned adapters.
	@server
	@client
]=]

local Types = {}

export type TActionState = {
	PendingActionId: string?,
	PendingActionData: any?,
	CurrentActionId: string?,
	ActionData: any?,
	ActionState: string?,
}

export type TActorAdapter = {
	QueryActiveEntities: (self: TActorAdapter, frameContext: any) -> { number },
	GetBehaviorTree: (self: TActorAdapter, entity: number) -> any?,
	GetActionState: (self: TActorAdapter, entity: number) -> TActionState?,
	SetActionState: (self: TActorAdapter, entity: number, actionState: TActionState) -> (),
	ClearActionState: (self: TActorAdapter, entity: number) -> (),
	SetPendingAction: (self: TActorAdapter, entity: number, actionId: string, actionData: any?) -> (),
	UpdateLastTickTime: (self: TActorAdapter, entity: number, currentTime: number) -> (),
	ShouldEvaluate: (self: TActorAdapter, entity: number, currentTime: number) -> boolean,
	GetActorLabel: ((self: TActorAdapter) -> string?)?,
}

--[=[
	Callback bundle required to build one actor adapter.
	@within AiAdapterFactoryTypes
	@interface TConfig
	.ActorLabel string? -- Optional label returned through `GetActorLabel()`
	.QueryActiveEntities (frameContext: any) -> { number } -- Returns the active entities for the current frame
	.GetBehaviorTree (entity: number) -> any? -- Returns the stored behavior-tree payload
	.GetActionState (entity: number) -> TActionState? -- Returns the authoritative action state
	.SetActionState (entity: number, actionState: TActionState) -> () -- Persists the resolved action state
	.ClearActionState (entity: number) -> () -- Clears invalid or failed action state
	.SetPendingAction (entity: number, actionId: string, actionData: any?) -> () -- Writes pending action requests during tree evaluation
	.UpdateLastTickTime (entity: number, currentTime: number) -> () -- Stores the last successful tree-evaluation timestamp
	.ShouldEvaluate (entity: number, currentTime: number) -> boolean -- Returns whether the entity should evaluate this frame
]=]
export type TConfig = {
	ActorLabel: string?,
	QueryActiveEntities: (frameContext: any) -> { number },
	GetBehaviorTree: (entity: number) -> any?,
	GetActionState: (entity: number) -> TActionState?,
	SetActionState: (entity: number, actionState: TActionState) -> (),
	ClearActionState: (entity: number) -> (),
	SetPendingAction: (entity: number, actionId: string, actionData: any?) -> (),
	UpdateLastTickTime: (entity: number, currentTime: number) -> (),
	ShouldEvaluate: (entity: number, currentTime: number) -> boolean,
}

type TFactoryQueryActiveEntities = string | ((factory: any, frameContext: any) -> { number })
type TFactoryGetBehaviorTree = string | ((factory: any, entity: number) -> any?)
type TFactoryGetActionState = string | ((factory: any, entity: number) -> TActionState?)
type TFactorySetActionState = string | ((factory: any, entity: number, actionState: TActionState) -> ())
type TFactoryClearActionState = string | ((factory: any, entity: number) -> ())
type TFactorySetPendingAction = string | ((factory: any, entity: number, actionId: string, actionData: any?) -> ())
type TFactoryUpdateLastTickTime = string | ((factory: any, entity: number, currentTime: number) -> ())
type TFactoryShouldEvaluate = string | ((factory: any, entity: number, currentTime: number) -> boolean)

export type TFactoryConfig = {
	ActorLabel: string?,
	Factory: any,
	QueryActiveEntities: TFactoryQueryActiveEntities,
	GetBehaviorTree: TFactoryGetBehaviorTree,
	GetActionState: TFactoryGetActionState,
	SetActionState: TFactorySetActionState,
	ClearActionState: TFactoryClearActionState,
	SetPendingAction: TFactorySetPendingAction,
	UpdateLastTickTime: TFactoryUpdateLastTickTime,
	ShouldEvaluate: TFactoryShouldEvaluate,
}

return table.freeze(Types)
