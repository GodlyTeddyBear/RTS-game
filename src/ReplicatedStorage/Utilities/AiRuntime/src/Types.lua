--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

--[=[
	@class AiRuntimeTypes
	Shared type definitions for `AiRuntime` configuration, hooks, adapters, and frame results.
	@server
	@client
]=]

local Types = {}

export type TConditionRegistry = { [string]: (options: any?) -> any }
export type TCommandRegistry = { [string]: (options: any?) -> any }

export type TActionState = {
	PendingActionId: string?,
	PendingActionData: any?,
	CurrentActionId: string?,
	ActionData: any?,
	ActionState: string?,
}

export type TActionDefinition = {
	ActionId: string,
	CreateExecutor: (() -> any)?,
	Executor: any?,
}

--[=[
	Ordered hook module used to contribute facts, behavior context, and runtime services.
	@within AiRuntimeTypes
	@interface THook
	.Use (self: THook, entity: number, hookContext: THookContext) -> THookContribution? -- Returns merged frame contributions for one entity
]=]
export type THook = {
	Use: (self: THook, entity: number, hookContext: THookContext) -> THookContribution?,
}

--[=[
	Allowed contribution buckets returned by one hook.
	@within AiRuntimeTypes
	@interface THookContribution
	.Facts { [string]: any }? -- Fact payload exposed to behavior-tree conditions and commands
	.BehaviorContext { [string]: any }? -- Extra tree-context fields contributed by hooks
	.Services { [string]: any }? -- Extra runtime services merged into executor dispatch
]=]
export type THookContribution = {
	Facts: { [string]: any }?,
	BehaviorContext: { [string]: any }?,
	Services: { [string]: any }?,
}

--[=[
	Hook context provided to each hook invocation.
	@within AiRuntimeTypes
	@interface THookContext
	.Entity number -- Runtime entity id being evaluated
	.ActorType string -- Registered actor-type key
	.ActionState TActionState? -- Current action-state snapshot read from the adapter
	.FrameContext TFrameContext -- Current frame inputs
	.Services { [string]: any } -- Base frame service bag before hook merging
	.Adapter TActorAdapter -- Registered adapter for the actor type
]=]
export type THookContext = {
	Entity: number,
	ActorType: string,
	ActionState: TActionState?,
	FrameContext: TFrameContext,
	Services: { [string]: any },
	Adapter: TActorAdapter,
}

--[=[
	Technical adapter that keeps authoritative AI state inside the owning context.
	@within AiRuntimeTypes
	@interface TActorAdapter
	.QueryActiveEntities (self: TActorAdapter, frameContext: TFrameContext) -> { number } -- Returns active runtime entities for the frame
	.GetBehaviorTree (self: TActorAdapter, entity: number) -> any? -- Returns the stored behavior-tree payload
	.GetActionState (self: TActorAdapter, entity: number) -> TActionState? -- Returns the authoritative action state
	.SetActionState (self: TActorAdapter, entity: number, actionState: TActionState) -> () -- Persists the resolved action state
	.ClearActionState (self: TActorAdapter, entity: number) -> () -- Clears invalid or failed action state
	.SetPendingAction (self: TActorAdapter, entity: number, actionId: string, actionData: any?) -> () -- Pending-action write surface used by command nodes
	.UpdateLastTickTime (self: TActorAdapter, entity: number, currentTime: number) -> () -- Stores the last successful tree-evaluation timestamp
	.ShouldEvaluate (self: TActorAdapter, entity: number, currentTime: number) -> boolean -- Returns whether the entity should evaluate its tree this frame
	.GetActorLabel (self: TActorAdapter) -> string? -- Optional diagnostic label used by defects
]=]
export type TActorAdapter = {
	QueryActiveEntities: (self: TActorAdapter, frameContext: TFrameContext) -> { number },
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
	Optional error-sink payload emitted for runtime defects.
	@within AiRuntimeTypes
	@interface TErrorSinkPayload
	.Stage string -- Failing runtime stage such as `HookRun`, `TreeRun`, `StartPendingAction`, or `TickCurrentAction`
	.ActorType string -- Registered actor-type key
	.ActorLabel string? -- Optional adapter-provided display label
	.Entity number -- Runtime entity id involved in the defect
	.ErrorType string -- Normalized defect type label
	.ErrorMessage string -- Human-readable defect summary
	.Details { [string]: any }? -- Optional structured defect metadata
]=]
export type TErrorSinkPayload = {
	Stage: string,
	ActorType: string,
	ActorLabel: string?,
	Entity: number,
	ErrorType: string,
	ErrorMessage: string,
	Details: { [string]: any }?,
}

--[=[
	Frame inputs consumed by `RunFrame`.
	@within AiRuntimeTypes
	@interface TFrameContext
	.CurrentTime number -- Shared frame timestamp used for tree-evaluation gating and action timestamps
	.DeltaTime number? -- Optional frame delta forwarded to executors
	.Services { [string]: any }? -- Optional base service bag exposed to hooks and executors
	.ActorTypes { string }? -- Optional actor-type filter for this frame
]=]
export type TFrameContext = {
	CurrentTime: number,
	DeltaTime: number?,
	Services: { [string]: any }?,
	ActorTypes: { string }?,
}

--[=[
	Per-entity runtime summary returned from `RunFrame`.
	@within AiRuntimeTypes
	@interface TRunFrameEntityResult
	.ActorType string -- Registered actor-type key
	.Entity number -- Runtime entity id
	.TreeStatus string -- `SkippedNoTree`, `SkippedNotReady`, `Ran`, or `TreeDefect`
	.StartStatus string? -- Start transition status returned from `StartPendingAction`
	.CommitStatus string? -- Commit transition status returned from `CommitStartedAction`
	.TickStatus string? -- Tick status returned from `TickCurrentAction`
	.ResolveStatus string? -- Resolve status returned from `ResolveFinishedAction`
]=]
export type TRunFrameEntityResult = {
	ActorType: string,
	Entity: number,
	TreeStatus: string,
	StartStatus: string?,
	CommitStatus: string?,
	TickStatus: string?,
	ResolveStatus: string?,
}

--[=[
	Frame summary returned from `RunFrame`.
	@within AiRuntimeTypes
	@interface TRunFrameResult
	.EntityResults { TRunFrameEntityResult } -- Per-entity runtime summaries for the frame
	.Defects { TErrorSinkPayload } -- Structured defects collected while the frame ran
]=]
export type TRunFrameResult = {
	EntityResults: { TRunFrameEntityResult },
	Defects: { TErrorSinkPayload },
}

--[=[
	Runtime configuration bundle required to construct `AiRuntime`.
	@within AiRuntimeTypes
	@interface TConfig
	.Conditions TConditionRegistry -- Condition builders used to compile behavior trees
	.Commands TCommandRegistry -- Command builders used to compile behavior trees
	.Hooks { THook } -- Ordered hook modules used to compose facts and services
	.ErrorSink ((payload: TErrorSinkPayload) -> ())? -- Optional defect sink invoked without logging inside the utility
]=]
export type TConfig = {
	Conditions: TConditionRegistry,
	Commands: TCommandRegistry,
	Hooks: { THook },
	ErrorSink: ((payload: TErrorSinkPayload) -> ())?,
}

--[=[
	Result returned by the safe executor-boundary runtime calls used internally by `AiRuntime`.
	@within AiRuntimeTypes
	@type TBehaviorTryResult Result.Result<any>
]=]
export type TBehaviorTryResult = Result.Result<any>

return table.freeze(Types)
