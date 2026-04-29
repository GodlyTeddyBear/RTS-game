--!strict

--[=[
	@class CancelCurrentAction
	Cancels the active executor for an action-state and returns a structured result.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExecutorBoundary = require(script.Parent.ExecutorBoundary)
local RuntimeContextAdapter = require(script.Parent.RuntimeContextAdapter)
local Result = require(ReplicatedStorage.Utilities.Result)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local Ok = Result.Ok

type TActionState = Types.TActionState
type TActionRuntimeContext = Types.TActionRuntimeContext
type TExecutor = Types.TExecutor
type TCancelActionResult = Types.TCancelActionResult
type TTryCancelActionResult = Types.TTryCancelActionResult

local CancelCurrentAction = {}

--[=[
	Cancels the active executor for an action-state and returns a structured result.
	@within CancelCurrentAction
	@param entity number -- Runtime entity id whose current action should cancel
	@param actionState TActionState -- Owning action-state table
	@param runtimeContext TActionRuntimeContext -- Context bag used to derive executor services
	@param executors { [string]: TExecutor } -- Registered executors keyed by action id
	@return TTryCancelActionResult -- Structured cancel result or a defect from the executor boundary
]=]
function CancelCurrentAction.TryExecute(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext,
	executors: { [string]: TExecutor }
): TTryCancelActionResult
	-- Exit early when there is no current action to cancel
	local currentActionId = actionState.CurrentActionId
	if type(currentActionId) ~= "string" or #currentActionId == 0 then
		return Ok({
			Status = "NoCurrentAction",
			ActionId = nil,
		})
	end

	-- Report missing executors explicitly so the owning context can reconcile state
	local executor = executors[currentActionId]
	if executor == nil then
		return Ok({
			Status = "MissingAction",
			ActionId = currentActionId,
		})
	end

	-- Cancel defensively so cleanup failures do not escape the runtime boundary
	local executorServices = RuntimeContextAdapter.GetExecutorServices(runtimeContext)
	local cancelResult = ExecutorBoundary.TryCancel(executor, currentActionId, entity, executorServices)
	if not cancelResult.success then
		return cancelResult
	end

	return Ok({
		Status = "Cancelled",
		ActionId = currentActionId,
	})
end

return table.freeze(CancelCurrentAction)
