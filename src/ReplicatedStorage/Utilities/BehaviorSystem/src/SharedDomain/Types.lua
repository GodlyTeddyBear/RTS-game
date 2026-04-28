--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

--[=[
	@class BehaviorSystemTypes
	Shared type definitions for BehaviorSystem registries, builder config, and symbolic tree nodes.
	@server
	@client
]=]

local Types = {}

--[=[
	Builder function that creates a condition task from optional configuration.
	@within BehaviorSystemTypes
	@type TConditionBuilder (options: any?) -> any
]=]
export type TConditionBuilder = (options: any?) -> any

--[=[
	Builder function that creates a command task from optional configuration.
	@within BehaviorSystemTypes
	@type TCommandBuilder (options: any?) -> any
]=]
export type TCommandBuilder = (options: any?) -> any

--[=[
	Registry map from condition symbol names to builder functions.
	@within BehaviorSystemTypes
	@type TConditionRegistry { [string]: TConditionBuilder }
]=]
export type TConditionRegistry = { [string]: TConditionBuilder }

--[=[
	Registry map from command symbol names to builder functions.
	@within BehaviorSystemTypes
	@type TCommandRegistry { [string]: TCommandBuilder }
]=]
export type TCommandRegistry = { [string]: TCommandBuilder }

--[=[
	Registry bundle required to construct a BehaviorSystem builder.
	@within BehaviorSystemTypes
	@interface TBuilderConfig
	.Conditions TConditionRegistry -- Condition builder registry used to resolve leaf symbols
	.Commands TCommandRegistry -- Command builder registry used to resolve leaf symbols
]=]
export type TBuilderConfig = {
	Conditions: TConditionRegistry,
	Commands: TCommandRegistry,
}

--[=[
	Sequence node shape used by symbolic behavior definitions.
	@within BehaviorSystemTypes
	@interface TBehaviorSequenceNode
	.Sequence { TBehaviorDefinitionNode } -- Ordered child nodes evaluated left to right
]=]
export type TBehaviorSequenceNode = {
	Sequence: { TBehaviorDefinitionNode },
}

--[=[
	Priority node shape used by symbolic behavior definitions.
	@within BehaviorSystemTypes
	@interface TBehaviorPriorityNode
	.Priority { TBehaviorDefinitionNode } -- Ordered child nodes evaluated until one succeeds
]=]
export type TBehaviorPriorityNode = {
	Priority: { TBehaviorDefinitionNode },
}

--[=[
	Symbolic behavior definitions accepted by the builder and validator.
	@within BehaviorSystemTypes
	@type TBehaviorDefinitionNode string | TBehaviorSequenceNode | TBehaviorPriorityNode
]=]
export type TBehaviorDefinitionNode = string | TBehaviorSequenceNode | TBehaviorPriorityNode

--[=[
	Runtime context bag forwarded to executor lifecycle methods by the shared dispatcher.
	@within BehaviorSystemTypes
	@interface TActionRuntimeContext
	.DeltaTime number? -- Optional frame delta used by `TickCurrentAction`
	.Dt number? -- Optional alias for `DeltaTime`
	.Services any? -- Optional service bag extracted and forwarded to executors
]=]
export type TActionRuntimeContext = {
	DeltaTime: number?,
	Dt: number?,
	Services: any?,
}

--[=[
	Service bag extracted from `TActionRuntimeContext` and forwarded to executor lifecycle methods.
	@within BehaviorSystemTypes
	@type TExecutorServices any
]=]
export type TExecutorServices = any

--[=[
	Generic executor lifecycle surface used by the shared runtime dispatcher.
	@within BehaviorSystemTypes
	@interface TExecutor
	.Start (self: TExecutor, entity: number, data: any?, services: TExecutorServices) -> (boolean, string?) -- Starts the action with the extracted service bag
	.Tick (self: TExecutor, entity: number, dt: number, services: TExecutorServices) -> string -- Advances the action and returns status
	.Cancel (self: TExecutor, entity: number, services: TExecutorServices) -> () -- Cancels the action with the extracted service bag
	.Complete (self: TExecutor, entity: number, services: TExecutorServices) -> () -- Finalizes the action after success
]=]
export type TExecutor = {
	Start: (self: TExecutor, entity: number, data: any?, services: TExecutorServices) -> (boolean, string?),
	Tick: (self: TExecutor, entity: number, dt: number, services: TExecutorServices) -> string,
	Cancel: (self: TExecutor, entity: number, services: TExecutorServices) -> (),
	Complete: (self: TExecutor, entity: number, services: TExecutorServices) -> (),
	Death: (self: TExecutor, entity: number, services: TExecutorServices) -> (),
}

--[=[
	Shared action registration contract used by the runtime dispatcher.
	@within BehaviorSystemTypes
	@interface TActionDefinition
	.ActionId string -- Stable action id used for registration and lookup
	.CreateExecutor (() -> TExecutor)? -- Factory used to build one executor instance for the action
	.Executor TExecutor? -- Prebuilt executor instance used directly instead of a factory
]=]
export type TActionDefinition = {
	ActionId: string,
	CreateExecutor: (() -> TExecutor)?,
	Executor: TExecutor?,
}

--[=[
	Shared action state bag read by the runtime dispatcher. The owning context still stores and mutates this state.
	@within BehaviorSystemTypes
	@interface TActionState
	.PendingActionId string? -- Requested action id awaiting transition into active execution
	.PendingActionData any? -- Payload for the pending action
	.CurrentActionId string? -- Currently running action id
	.ActionData any? -- Payload for the current action
	.ActionState string? -- Optional domain-local state label such as `Running` or `Committed`
]=]
export type TActionState = {
	PendingActionId: string?,
	PendingActionData: any?,
	CurrentActionId: string?,
	ActionData: any?,
	ActionState: string?,
}

--[=[
	Result returned when attempting to start a pending action through the shared dispatcher.
	@within BehaviorSystemTypes
	@interface TStartActionResult
	.Status string -- `NoAction`, `Blocked`, `NoChange`, `MissingAction`, `FailedToStart`, `Started`, or `Replaced`
	.ActionId string? -- Action id involved in the attempt
	.ReplacedActionId string? -- Previous current action id when one was cancelled before a replacement
	.FailureReason string? -- Optional executor-provided start failure reason
]=]
export type TStartActionResult = {
	Status: string,
	ActionId: string?,
	ReplacedActionId: string?,
	FailureReason: string?,
}

--[=[
	Result returned when the shared runtime applies a generic start commit to the owning context's action-state table.
	@within BehaviorSystemTypes
	@interface TCommitStartResult
	.Status string -- `Committed`, `Skipped`, or `InvalidResult`
	.ActionId string? -- Action id that was committed into current action state
]=]
export type TCommitStartResult = {
	Status: string,
	ActionId: string?,
}

--[=[
	Result returned when ticking the current action through the shared dispatcher.
	@within BehaviorSystemTypes
	@interface TTickActionResult
	.Status string -- `NoCurrentAction`, `MissingAction`, `Running`, `Success`, or `Fail`
	.ActionId string? -- Action id involved in the tick
]=]
export type TTickActionResult = {
	Status: string,
	ActionId: string?,
}

--[=[
	Result returned when the shared runtime resolves a finished action into idle state.
	@within BehaviorSystemTypes
	@interface TResolveFinishedActionResult
	.Status string -- `Resolved`, `Skipped`, or `InvalidResult`
	.ActionId string? -- Action id that was resolved out of current action state
]=]
export type TResolveFinishedActionResult = {
	Status: string,
	ActionId: string?,
}

--[=[
	Result returned when cancelling the current action through the shared dispatcher.
	@within BehaviorSystemTypes
	@interface TCancelActionResult
	.Status string -- `NoCurrentAction`, `MissingAction`, or `Cancelled`
	.ActionId string? -- Action id involved in the cancellation
]=]
export type TCancelActionResult = {
	Status: string,
	ActionId: string?,
}

--[=[
	Result returned when handling forced actor removal through the shared dispatcher.
	@within BehaviorSystemTypes
	@interface TDeathActionResult
	.Status string -- `NoCurrentAction`, `MissingAction`, or `Handled`
	.ActionId string? -- Action id involved in the death handling.
]=]
export type TDeathActionResult = {
	Status: string,
	ActionId: string?,
}

--[=[
	Result returned by the safe executor-boundary start API.
	@within BehaviorSystemTypes
	@type TTryStartActionResult Result.Result<TStartActionResult>
]=]
export type TTryStartActionResult = Result.Result<TStartActionResult>

--[=[
	Result returned by the safe executor-boundary tick API.
	@within BehaviorSystemTypes
	@type TTryTickActionResult Result.Result<TTickActionResult>
]=]
export type TTryTickActionResult = Result.Result<TTickActionResult>

--[=[
	Result returned by the safe executor-boundary cancel API.
	@within BehaviorSystemTypes
	@type TTryCancelActionResult Result.Result<TCancelActionResult>
]=]
export type TTryCancelActionResult = Result.Result<TCancelActionResult>

--[=[
	Result returned by the safe executor-boundary death API.
	@within BehaviorSystemTypes
	@type TTryDeathActionResult Result.Result<TDeathActionResult>
]=]
export type TTryDeathActionResult = Result.Result<TDeathActionResult>

return table.freeze(Types)
