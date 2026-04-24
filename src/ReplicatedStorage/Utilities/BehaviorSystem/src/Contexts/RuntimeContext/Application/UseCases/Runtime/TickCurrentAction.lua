--!strict

--[=[
	@class TickCurrentAction
	Ticks the active executor for an action-state and normalizes its terminal status.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionId = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ValueObjects.ActionId)
local TickStatus = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ValueObjects.TickStatus)
local ExecutorBoundary = require(script.Parent.ExecutorBoundary)
local RuntimeContextAdapter = require(script.Parent.RuntimeContextAdapter)
local Result = require(ReplicatedStorage.Utilities.Result)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local Ok = Result.Ok

type TActionState = Types.TActionState
type TActionRuntimeContext = Types.TActionRuntimeContext
type TExecutor = Types.TExecutor
type TTickActionResult = Types.TTickActionResult
type TTryTickActionResult = Types.TTryTickActionResult

local TickCurrentAction = {}

-- Package the tick outcome into the shared runtime result shape.
local function _createResult(status: string, actionId: string?): TTickActionResult
	return {
		Status = status,
		ActionId = actionId,
	}
end

--[=[
	Ticks the current action through the executor boundary and normalizes the result status.
	@within TickCurrentAction
	@param entity number -- Runtime entity id whose current action should tick
	@param actionState TActionState -- Owning action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services and delta time
	@param executors { [string]: TExecutor } -- Registered executors keyed by action id
	@return TTryTickActionResult -- Structured tick result or a defect from the executor boundary
]=]
function TickCurrentAction.TryExecute(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext,
	executors: { [string]: TExecutor }
): TTryTickActionResult
	-- Read the current action id and exit early when nothing is active
	local currentActionId = actionState.CurrentActionId
	if type(currentActionId) ~= "string" then
		return Ok(_createResult("NoCurrentAction", nil))
	end
	currentActionId = ActionId.From(currentActionId, "actionState.CurrentActionId")

	-- Look up the executor for the active action before ticking it
	local executor = executors[currentActionId]
	if executor == nil then
		return Ok(_createResult("MissingAction", currentActionId))
	end

	-- Extract execution inputs from the runtime context bag
	local executorServices = RuntimeContextAdapter.GetExecutorServices(runtimeContext)
	local deltaTime = RuntimeContextAdapter.GetDeltaTime(runtimeContext)

	-- Tick defensively so executor failures collapse into a fail result
	local tickResult = ExecutorBoundary.TryTick(executor, currentActionId, entity, deltaTime, executorServices)
	if not tickResult.success then
		return tickResult
	end

	local status = tickResult.value

	-- Normalize invalid executor statuses to fail so the runtime stays in a known state
	if not TickStatus.IsValid(status) then
		status = "Fail"
	end

	if status == "Success" then
		-- Success requires executor completion before reporting the terminal result
		local completeResult = ExecutorBoundary.TryComplete(executor, currentActionId, entity, executorServices)
		if not completeResult.success then
			return completeResult
		end

		return Ok(_createResult("Success", currentActionId))
	end

	if status == "Running" then
		-- Running keeps the action active without cleanup
		return Ok(_createResult("Running", currentActionId))
	end

	-- Any other terminal path cancels the executor and reports failure
	local cancelResult = ExecutorBoundary.TryCancel(executor, currentActionId, entity, executorServices)
	if not cancelResult.success then
		return cancelResult
	end

	return Ok(_createResult("Fail", currentActionId))
end

return table.freeze(TickCurrentAction)
