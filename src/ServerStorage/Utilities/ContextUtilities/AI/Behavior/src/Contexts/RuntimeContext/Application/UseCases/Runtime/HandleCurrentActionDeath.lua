--!strict

--[=[
	@class HandleCurrentActionDeath
	Handles forced actor removal for the active executor and returns a structured result.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeEnums = require(ReplicatedStorage.Utilities.AI.Runtime.src.RuntimeEnums)
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

local function _createResult(status: any, actionId: string?): TDeathActionResult
	return {
		Status = status.Name,
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
		return Ok(_createResult(RuntimeEnums.DeathStatus.NoCurrentAction, nil))
	end

	local executor = executors[currentActionId]
	if executor == nil then
		return Ok(_createResult(RuntimeEnums.DeathStatus.MissingAction, currentActionId))
	end

	local executorServices = RuntimeContextAdapter.GetExecutorServices(runtimeContext)
	local deathResult = ExecutorBoundary.TryDeath(executor, currentActionId, entity, executorServices)
	if not deathResult.success then
		return deathResult
	end

	return Ok(_createResult(RuntimeEnums.DeathStatus.Handled, currentActionId))
end

return table.freeze(HandleCurrentActionDeath)
