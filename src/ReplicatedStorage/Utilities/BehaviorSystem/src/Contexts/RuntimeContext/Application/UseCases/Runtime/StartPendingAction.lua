--!strict

--[=[
	@class StartPendingAction
	Starts the pending executor for an action-state and returns a structured transition result.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionId = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ValueObjects.ActionId)
local ActionStateTransitionSpec = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Specs.ActionStateTransitionSpec)
local ExecutorBoundary = require(script.Parent.ExecutorBoundary)
local RuntimeContextAdapter = require(script.Parent.RuntimeContextAdapter)
local Result = require(ReplicatedStorage.Utilities.Result)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local Ok = Result.Ok

type TActionState = Types.TActionState
type TActionRuntimeContext = Types.TActionRuntimeContext
type TExecutor = Types.TExecutor
type TStartActionResult = Types.TStartActionResult
type TTryStartActionResult = Types.TTryStartActionResult

local StartPendingAction = {}

-- Package the pending-start outcome into the shared runtime result shape.
local function _createResult(
	status: string,
	actionId: string?,
	replacedActionId: string?,
	failureReason: string?
): TStartActionResult
	return {
		Status = status,
		ActionId = actionId,
		ReplacedActionId = replacedActionId,
		FailureReason = failureReason,
	}
end

--[=[
	Attempts to promote the pending action to the current action through the executor boundary.
	@within StartPendingAction
	@param entity number -- Runtime entity id whose action should start
	@param actionState TActionState -- Owning action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services
	@param executors { [string]: TExecutor } -- Registered executors keyed by action id
	@return TTryStartActionResult -- Structured start result or a defect from the executor boundary
]=]
function StartPendingAction.TryExecute(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext,
	executors: { [string]: TExecutor }
): TTryStartActionResult
	-- Read the pending action id and exit early when nothing is waiting to start
	local pendingActionId = actionState.PendingActionId
	if type(pendingActionId) ~= "string" then
		return Ok(_createResult("NoAction", nil, nil, nil))
	end
	pendingActionId = ActionId.From(pendingActionId, "actionState.PendingActionId")

	-- Block transitions when the owning action-state is not allowed to start
	local canStart, blockedReason = ActionStateTransitionSpec.CanStartFromActionState(actionState.ActionState)
	if not canStart then
		return Ok(_createResult("Blocked", pendingActionId, nil, blockedReason))
	end

	-- Resolve runtime services and detect whether the pending action replaces an active one
	local executorServices = RuntimeContextAdapter.GetExecutorServices(runtimeContext)
	local currentActionId = actionState.CurrentActionId
	local replacedActionId = nil :: string?

	if type(currentActionId) == "string" then
		currentActionId = ActionId.From(currentActionId, "actionState.CurrentActionId")
		if currentActionId == pendingActionId then
			return Ok(_createResult("NoChange", pendingActionId, nil, nil))
		end

		local currentExecutor = executors[currentActionId]
		if currentExecutor ~= nil then
			local cancelResult = ExecutorBoundary.TryCancel(currentExecutor, currentActionId, entity, executorServices)
			if not cancelResult.success then
				return cancelResult
			end
		end
		replacedActionId = currentActionId
	end

	-- Look up the pending executor before attempting the start transition
	local nextExecutor = executors[pendingActionId]
	if nextExecutor == nil then
		return Ok(_createResult("MissingAction", pendingActionId, replacedActionId, nil))
	end

	-- Start the executor defensively so executor errors become a failed result instead of a hard crash
	local startResult = ExecutorBoundary.TryStart(nextExecutor, pendingActionId, entity, actionState.PendingActionData, executorServices)
	if not startResult.success then
		return startResult
	end

	local startInvocation = startResult.value
	if not startInvocation.Success then
		return Ok(_createResult("FailedToStart", pendingActionId, replacedActionId, startInvocation.FailureReason))
	end

	local status = if replacedActionId ~= nil then "Replaced" else "Started"
	return Ok(_createResult(status, pendingActionId, replacedActionId, nil))
end

return table.freeze(StartPendingAction)
