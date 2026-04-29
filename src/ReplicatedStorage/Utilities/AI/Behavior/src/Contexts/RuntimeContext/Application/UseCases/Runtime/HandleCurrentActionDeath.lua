--!strict

--[=[
	@class HandleCurrentActionDeath
	Handles forced actor removal for the active executor and returns a structured result.
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
type TDeathActionResult = Types.TDeathActionResult
type TTryDeathActionResult = Types.TTryDeathActionResult

local HandleCurrentActionDeath = {}

local function _createResult(status: string, actionId: string?): TDeathActionResult
	return {
		Status = status,
		ActionId = actionId,
	}
end

function HandleCurrentActionDeath.TryExecute(
	entity: number,
	actionState: TActionState,
	runtimeContext: TActionRuntimeContext,
	executors: { [string]: TExecutor }
): TTryDeathActionResult
	local currentActionId = actionState.CurrentActionId
	if type(currentActionId) ~= "string" or currentActionId == "" then
		return Ok(_createResult("NoCurrentAction", nil))
	end

	local executor = executors[currentActionId]
	if executor == nil then
		return Ok(_createResult("MissingAction", currentActionId))
	end

	local executorServices = RuntimeContextAdapter.GetExecutorServices(runtimeContext)
	local deathResult = ExecutorBoundary.TryDeath(executor, currentActionId, entity, executorServices)
	if not deathResult.success then
		return deathResult
	end

	return Ok(_createResult("Handled", currentActionId))
end

return table.freeze(HandleCurrentActionDeath)
