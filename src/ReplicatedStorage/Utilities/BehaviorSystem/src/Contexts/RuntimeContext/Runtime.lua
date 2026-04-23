--!strict

--[=[
	@class BehaviorSystemRuntime
	Facade that combines behavior-tree building with generic action registration and executor lifecycle dispatch.
	@server
	@client
]=]

local ActionAssertions = require(script.Parent.Parent.Parent.SharedDomain.Assertions.ActionAssertions)
local ActionId = require(script.Parent.Parent.Parent.SharedDomain.ValueObjects.ActionId)
local Builder = require(script.Parent.Parent.BuildContext.Builder)
local StartPendingAction = require(script.Parent.Application.UseCases.Runtime.StartPendingAction)
local CommitStartedAction = require(script.Parent.Application.UseCases.Runtime.CommitStartedAction)
local TickCurrentAction = require(script.Parent.Application.UseCases.Runtime.TickCurrentAction)
local ResolveFinishedAction = require(script.Parent.Application.UseCases.Runtime.ResolveFinishedAction)
local CancelCurrentAction = require(script.Parent.Application.UseCases.Runtime.CancelCurrentAction)
local Types = require(script.Parent.Parent.Parent.SharedDomain.Types)

type TBuilderConfig = Types.TBuilderConfig
type TActionDefinition = Types.TActionDefinition
type TActionState = Types.TActionState
type TActionRuntimeContext = Types.TActionRuntimeContext
type TStartActionResult = Types.TStartActionResult
type TCommitStartResult = Types.TCommitStartResult
type TTickActionResult = Types.TTickActionResult
type TResolveFinishedActionResult = Types.TResolveFinishedActionResult
type TCancelActionResult = Types.TCancelActionResult
type TTryStartActionResult = Types.TTryStartActionResult
type TTryTickActionResult = Types.TTryTickActionResult
type TTryCancelActionResult = Types.TTryCancelActionResult

local Runtime = {}
Runtime.__index = Runtime

local assertActionDefinition = ActionAssertions.AssertActionDefinition
local assertActionId = ActionAssertions.AssertActionId
local assertActionState = ActionAssertions.AssertActionState
local assertExecutor = ActionAssertions.AssertExecutor

--[=[
	Creates a runtime facade with a configured behavior builder.
	@within BehaviorSystemRuntime
	@param config TBuilderConfig -- Condition and command registries used for tree compilation
	@return BehaviorSystemRuntime -- Runtime facade that can also register and dispatch actions
]=]
function Runtime.new(config: TBuilderConfig)
	-- Build the shared definition compiler and initialize action registries
	local self = setmetatable({}, Runtime)
	self._builder = Builder.new(config)
	self._actions = {}
	self._executors = {}
	return self
end

--[=[
	Validates a symbolic behavior definition against the runtime's registries.
	@within BehaviorSystemRuntime
	@param definition TBehaviorDefinitionNode -- Symbolic tree root to validate
]=]
function Runtime:Validate(definition: Types.TBehaviorDefinitionNode)
	self._builder:Validate(definition)
end

--[=[
	Builds a concrete behavior tree from a symbolic definition.
	@within BehaviorSystemRuntime
	@param definition TBehaviorDefinitionNode -- Symbolic tree root to compile
	@return BehaviorTree -- Compiled behavior tree instance
]=]
function Runtime:BuildTree(definition: Types.TBehaviorDefinitionNode)
	return self._builder:Build(definition)
end

--[=[
	Registers one action definition and stores its executor instance for runtime dispatch.
	@within BehaviorSystemRuntime
	@param definition TActionDefinition -- Action registration contract
]=]
function Runtime:RegisterAction(definition: TActionDefinition)
	-- Validate the action definition before touching the runtime registries
	assertActionDefinition(definition)

	-- Normalize the action id and reject duplicate registrations
	local actionId = ActionId.From(definition.ActionId, "action definition ActionId")
	assert(self._actions[actionId] == nil, ("BehaviorSystem action '%s' is already registered"):format(actionId))

	-- Materialize the executor once so registration and dispatch share the same instance
	local executor = definition.Executor
	if executor == nil then
		executor = definition.CreateExecutor()
	end
	assertExecutor(executor, actionId)

	self._actions[actionId] = definition
	self._executors[actionId] = executor
end

--[=[
	Registers a table of action definitions keyed by any stable name.
	@within BehaviorSystemRuntime
	@param definitions { [any]: TActionDefinition } -- Action definitions to register
]=]
function Runtime:RegisterActions(definitions: { [any]: TActionDefinition })
	-- Validate the container before iterating over its action definitions
	assert(type(definitions) == "table", "BehaviorSystem:RegisterActions requires a definition table")

	-- Register each definition through the single-action path so validation stays centralized
	for _, definition in pairs(definitions) do
		self:RegisterAction(definition)
	end
end

--[=[
	Returns the executor instance registered for the requested action id.
	@within BehaviorSystemRuntime
	@param actionId string -- Action id to resolve
	@return TExecutor? -- Registered executor instance or `nil`
]=]
function Runtime:GetExecutor(actionId: string)
	-- Normalize the lookup key so callers can pass any valid action-id string
	assertActionId(actionId, "actionId")
	return self._executors[ActionId.From(actionId, "actionId")]
end

--[=[
	Starts the pending action described by the supplied action state.
	The owning context remains responsible for mutating action-state storage after interpreting the result.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose action should start
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@return TStartActionResult -- Generic dispatch result for the owning context to interpret
]=]
function Runtime:StartPendingAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TStartActionResult
	-- Validate the action-state table before delegating to the shared start use case
	assertActionState(actionState)
	return StartPendingAction.Execute(entity, actionState, runtimeContext, self._executors)
end

--[=[
	Starts the pending action through the safe executor-boundary API.
	Returns `Ok(TStartActionResult)` for normal runtime outcomes and a `Defect` when executor code crashes.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose action should start
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@return TTryStartActionResult -- Structured result carrying the normal start record or an executor defect
]=]
function Runtime:TryStartPendingAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TTryStartActionResult
	assertActionState(actionState)
	return StartPendingAction.TryExecute(entity, actionState, runtimeContext, self._executors)
end

--[=[
	Commits a successfully started pending action into the owning context's action-state table.
	This helper performs only the generic pending-to-current transition and does not apply domain-specific consequences.
	@within BehaviorSystemRuntime
	@param actionState TActionState -- Owning context's action-state table
	@param startResult TStartActionResult -- Result returned from `StartPendingAction`
	@param startedAt any? -- Optional timestamp or transition marker stored on `StartedAt`
	@return TCommitStartResult -- Generic commit result
]=]
function Runtime:CommitStartedAction(
	actionState: TActionState,
	startResult: TStartActionResult,
	startedAt: any?
): TCommitStartResult
	-- Validate the action-state table before delegating to the shared commit use case
	assertActionState(actionState)
	return CommitStartedAction.Execute(actionState, startResult, startedAt)
end

--[=[
	Ticks the current action described by the supplied action state.
	The owning context remains responsible for deciding how to mutate action-state storage after interpreting the result.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose current action should tick
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@return TTickActionResult -- Generic tick result for the owning context to interpret
]=]
function Runtime:TickCurrentAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TTickActionResult
	-- Validate the action-state table before delegating to the shared tick use case
	assertActionState(actionState)
	return TickCurrentAction.Execute(entity, actionState, runtimeContext, self._executors)
end

--[=[
	Ticks the current action through the safe executor-boundary API.
	Returns `Ok(TTickActionResult)` for normal runtime outcomes and a `Defect` when executor code crashes.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose current action should tick
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@return TTryTickActionResult -- Structured result carrying the normal tick record or an executor defect
]=]
function Runtime:TryTickCurrentAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TTryTickActionResult
	assertActionState(actionState)
	return TickCurrentAction.TryExecute(entity, actionState, runtimeContext, self._executors)
end

--[=[
	Resolves a finished action into the generic idle state after a terminal tick result.
	This helper performs only generic current-action cleanup and leaves domain-specific consequences to the owning context.
	@within BehaviorSystemRuntime
	@param actionState TActionState -- Owning context's action-state table
	@param tickResult TTickActionResult -- Result returned from `TickCurrentAction`
	@param finishedAt any? -- Optional timestamp or transition marker stored on `FinishedAt`
	@return TResolveFinishedActionResult -- Generic resolution result
]=]
function Runtime:ResolveFinishedAction(
	actionState: TActionState,
	tickResult: TTickActionResult,
	finishedAt: any?
): TResolveFinishedActionResult
	-- Validate the action-state table before delegating to the shared resolve use case
	assertActionState(actionState)
	return ResolveFinishedAction.Execute(actionState, tickResult, finishedAt)
end

--[=[
	Executes a callback when the supplied tick result represents a successful action.
	When `actionId` is provided, the callback only runs when the successful action id matches.
	@within BehaviorSystemRuntime
	@param tickResult TTickActionResult -- Result returned from `TickCurrentAction`
	@param actionId string? -- Optional action id filter
	@param callback (tickResult: TTickActionResult) -> () -- Callback invoked on a matching success result
	@return boolean -- Whether the callback executed
]=]
function Runtime:OnActionSucceeded(
	tickResult: TTickActionResult,
	actionId: string?,
	callback: (tickResult: TTickActionResult) -> ()
): boolean
	-- Require a result table and callback before attempting the conditional dispatch
	assert(type(tickResult) == "table", "BehaviorSystem OnActionSucceeded requires a tickResult table")
	assert(type(callback) == "function", "BehaviorSystem OnActionSucceeded requires a callback")

	-- Only success results should reach the callback
	if tickResult.Status ~= "Success" then
		return false
	end

	-- Apply the optional action-id filter before invoking the callback
	if actionId ~= nil then
		assertActionId(actionId, "actionId")
		if tickResult.ActionId ~= actionId then
			return false
		end
	end

	callback(tickResult)
	return true
end

--[=[
	Cancels the current action described by the supplied action state.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose current action should cancel
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@return TCancelActionResult -- Generic cancellation result for the owning context to interpret
]=]
function Runtime:CancelCurrentAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TCancelActionResult
	-- Validate the action-state table before delegating to the shared cancel use case
	assertActionState(actionState)
	return CancelCurrentAction.Execute(entity, actionState, runtimeContext, self._executors)
end

--[=[
	Cancels the current action through the safe executor-boundary API.
	Returns `Ok(TCancelActionResult)` for normal runtime outcomes and a `Defect` when executor code crashes.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose current action should cancel
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@return TTryCancelActionResult -- Structured result carrying the normal cancel record or an executor defect
]=]
function Runtime:TryCancelCurrentAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TTryCancelActionResult
	assertActionState(actionState)
	return CancelCurrentAction.TryExecute(entity, actionState, runtimeContext, self._executors)
end

return table.freeze(Runtime)
