--!strict

--[=[
	@class BehaviorSystemRuntime
	Facade that combines behavior-tree building with generic action registration and executor lifecycle dispatch.
	@server
	@client
]=]

local ActionAssertions = require(script.Parent.Internal.ActionAssertions)
local Builder = require(script.Parent.Builder)
local Types = require(script.Parent.Types)

type TBuilderConfig = Types.TBuilderConfig
type TActionDefinition = Types.TActionDefinition
type TActionState = Types.TActionState
type TActionRuntimeContext = Types.TActionRuntimeContext
type TStartActionResult = Types.TStartActionResult
type TCommitStartResult = Types.TCommitStartResult
type TTickActionResult = Types.TTickActionResult
type TResolveFinishedActionResult = Types.TResolveFinishedActionResult
type TCancelActionResult = Types.TCancelActionResult

local Runtime = {}
Runtime.__index = Runtime

local function _getExecutorServices(runtimeContext: TActionRuntimeContext)
	if type(runtimeContext) ~= "table" then
		return runtimeContext
	end

	if runtimeContext.Services ~= nil then
		return runtimeContext.Services
	end

	return runtimeContext
end

local function _getDeltaTime(runtimeContext: TActionRuntimeContext): number
	if type(runtimeContext) ~= "table" then
		return 0
	end

	local deltaTime = runtimeContext.DeltaTime
	if type(deltaTime) == "number" then
		return deltaTime
	end

	local dt = runtimeContext.Dt
	if type(dt) == "number" then
		return dt
	end

	return 0
end

--[=[
	Creates a runtime facade with a configured behavior builder.
	@within BehaviorSystemRuntime
	@param config TBuilderConfig -- Condition and command registries used for tree compilation
	@return BehaviorSystemRuntime -- Runtime facade that can also register and dispatch actions
]=]
function Runtime.new(config: TBuilderConfig)
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
	ActionAssertions.AssertActionDefinition(definition)

	local actionId = definition.ActionId
	local executor = definition.Executor
	if executor == nil then
		executor = definition.CreateExecutor()
	end

	self._actions[actionId] = definition
	self._executors[actionId] = executor
end

--[=[
	Registers a table of action definitions keyed by any stable name.
	@within BehaviorSystemRuntime
	@param definitions { [any]: TActionDefinition } -- Action definitions to register
]=]
function Runtime:RegisterActions(definitions: { [any]: TActionDefinition })
	assert(type(definitions) == "table", "BehaviorSystem:RegisterActions requires a definition table")

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
	ActionAssertions.AssertActionId(actionId, "actionId")
	return self._executors[actionId]
end

--[=[
	Starts the pending action described by the supplied action state.
	The owning context remains responsible for mutating action-state storage after interpreting the result.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose action should start
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag forwarded to executors
	@return TStartActionResult -- Generic dispatch result for the owning context to interpret
]=]
function Runtime:StartPendingAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TStartActionResult
	ActionAssertions.AssertActionState(actionState)

	local pendingActionId = actionState.PendingActionId
	if type(pendingActionId) ~= "string" or #pendingActionId == 0 then
		return {
			Status = "NoAction",
			ActionId = nil,
			ReplacedActionId = nil,
			FailureReason = nil,
		}
	end

	if actionState.ActionState == "Committed" then
		return {
			Status = "Blocked",
			ActionId = pendingActionId,
			ReplacedActionId = nil,
			FailureReason = "Committed",
		}
	end

	local currentActionId = actionState.CurrentActionId
	if currentActionId == pendingActionId then
		return {
			Status = "NoChange",
			ActionId = pendingActionId,
			ReplacedActionId = nil,
			FailureReason = nil,
		}
	end

	local services = _getExecutorServices(runtimeContext)
	local replacedActionId = nil :: string?

	if type(currentActionId) == "string" and #currentActionId > 0 then
		local currentExecutor = self._executors[currentActionId]
		if currentExecutor ~= nil then
			pcall(function()
				currentExecutor:Cancel(entity, services)
			end)
		end
		replacedActionId = currentActionId
	end

	local nextExecutor = self._executors[pendingActionId]
	if nextExecutor == nil then
		return {
			Status = "MissingAction",
			ActionId = pendingActionId,
			ReplacedActionId = replacedActionId,
			FailureReason = nil,
		}
	end

	local startSuccess = false
	local failureReason = nil :: string?
	pcall(function()
		startSuccess, failureReason = nextExecutor:Start(entity, actionState.PendingActionData, services)
	end)

	if not startSuccess then
		return {
			Status = "FailedToStart",
			ActionId = pendingActionId,
			ReplacedActionId = replacedActionId,
			FailureReason = failureReason,
		}
	end

	return {
		Status = if replacedActionId ~= nil then "Replaced" else "Started",
		ActionId = pendingActionId,
		ReplacedActionId = replacedActionId,
		FailureReason = nil,
	}
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
	ActionAssertions.AssertActionState(actionState)
	assert(type(startResult) == "table", "BehaviorSystem CommitStartedAction requires a startResult table")

	if startResult.Status ~= "Started" and startResult.Status ~= "Replaced" then
		return {
			Status = "Skipped",
			ActionId = startResult.ActionId,
		}
	end

	local pendingActionId = actionState.PendingActionId
	if type(pendingActionId) ~= "string" or #pendingActionId == 0 then
		return {
			Status = "InvalidResult",
			ActionId = nil,
		}
	end

	actionState.CurrentActionId = pendingActionId
	actionState.ActionData = actionState.PendingActionData
	actionState.PendingActionId = nil
	actionState.PendingActionData = nil
	actionState.ActionState = "Running"

	if startedAt ~= nil then
		actionState.StartedAt = startedAt
	end

	return {
		Status = "Committed",
		ActionId = pendingActionId,
	}
end

--[=[
	Ticks the current action described by the supplied action state.
	The owning context remains responsible for deciding how to mutate action-state storage after interpreting the result.
	@within BehaviorSystemRuntime
	@param entity number -- Runtime entity id whose current action should tick
	@param actionState TActionState -- Owning context's action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag forwarded to executors
	@return TTickActionResult -- Generic tick result for the owning context to interpret
]=]
function Runtime:TickCurrentAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TTickActionResult
	ActionAssertions.AssertActionState(actionState)

	local currentActionId = actionState.CurrentActionId
	if type(currentActionId) ~= "string" or #currentActionId == 0 then
		return {
			Status = "NoCurrentAction",
			ActionId = nil,
		}
	end

	local executor = self._executors[currentActionId]
	if executor == nil then
		return {
			Status = "MissingAction",
			ActionId = currentActionId,
		}
	end

	local tickStatus = "Fail"
	pcall(function()
		tickStatus = executor:Tick(entity, _getDeltaTime(runtimeContext), _getExecutorServices(runtimeContext))
	end)

	if tickStatus == "Success" then
		pcall(function()
			executor:Complete(entity, _getExecutorServices(runtimeContext))
		end)

		return {
			Status = "Success",
			ActionId = currentActionId,
		}
	end

	if tickStatus == "Running" then
		return {
			Status = "Running",
			ActionId = currentActionId,
		}
	end

	if tickStatus == "Fail" then
		pcall(function()
			executor:Cancel(entity, _getExecutorServices(runtimeContext))
		end)
	end

	return {
		Status = "Fail",
		ActionId = currentActionId,
	}
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
	ActionAssertions.AssertActionState(actionState)
	assert(type(tickResult) == "table", "BehaviorSystem ResolveFinishedAction requires a tickResult table")

	local status = tickResult.Status
	if status == "Running" or status == "NoCurrentAction" then
		return {
			Status = "Skipped",
			ActionId = tickResult.ActionId,
		}
	end

	if status ~= "Success" and status ~= "Fail" and status ~= "MissingAction" then
		return {
			Status = "InvalidResult",
			ActionId = tickResult.ActionId,
		}
	end

	local resolvedActionId = actionState.CurrentActionId
	actionState.CurrentActionId = nil
	actionState.ActionData = nil
	actionState.ActionState = "Idle"

	if finishedAt ~= nil then
		actionState.FinishedAt = finishedAt
	end

	return {
		Status = "Resolved",
		ActionId = resolvedActionId,
	}
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
	assert(type(tickResult) == "table", "BehaviorSystem OnActionSucceeded requires a tickResult table")
	assert(type(callback) == "function", "BehaviorSystem OnActionSucceeded requires a callback")

	if tickResult.Status ~= "Success" then
		return false
	end

	if actionId ~= nil then
		ActionAssertions.AssertActionId(actionId, "actionId")
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
	@param runtimeContext TActionRuntimeContext -- Context bag forwarded to executors
	@return TCancelActionResult -- Generic cancellation result for the owning context to interpret
]=]
function Runtime:CancelCurrentAction(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext
): TCancelActionResult
	ActionAssertions.AssertActionState(actionState)

	local currentActionId = actionState.CurrentActionId
	if type(currentActionId) ~= "string" or #currentActionId == 0 then
		return {
			Status = "NoCurrentAction",
			ActionId = nil,
		}
	end

	local executor = self._executors[currentActionId]
	if executor == nil then
		return {
			Status = "MissingAction",
			ActionId = currentActionId,
		}
	end

	pcall(function()
		executor:Cancel(entity, _getExecutorServices(runtimeContext))
	end)

	return {
		Status = "Cancelled",
		ActionId = currentActionId,
	}
end

return table.freeze(Runtime)
