--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local ExecutorDefectTypes = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ExecutorDefectTypes)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local Ok = Result.Ok

type TExecutor = Types.TExecutor
type TExecutorServices = Types.TExecutorServices

local ExecutorBoundary = {}

type TStartInvocation = {
	Success: boolean,
	FailureReason: string?,
}

local function _createDefect(
	defectType: string,
	message: string,
	data: { [string]: any }?,
	traceback: string?
): Result.Err
	local defect = Result.Defect(message, traceback)
	defect.type = defectType
	defect.data = data
	return defect
end

local function _invokeExecutorMethod(
	executor: TExecutor,
	methodName: string,
	defectType: string,
	actionId: string,
	entity: number,
	...: any
): Result.Result<any>
	local arguments = table.pack(...)
	local invocationData = {
		ActionId = actionId,
		Entity = entity,
		Method = methodName,
	}

	local results = table.pack(xpcall(function()
		return (executor :: any)[methodName](executor, entity, table.unpack(arguments, 1, arguments.n))
	end, function(thrown)
		return _createDefect(defectType, tostring(thrown), invocationData, debug.traceback(nil, 2))
	end))

	if not results[1] then
		return results[2]
	end

	local invocationResults = table.pack(table.unpack(results, 2, results.n))
	return Ok(invocationResults)
end

function ExecutorBoundary.TryStart(
	executor: TExecutor,
	actionId: string,
	entity: number,
	actionData: any?,
	services: TExecutorServices
): Result.Result<TStartInvocation>
	local startResult = _invokeExecutorMethod(
		executor,
		"Start",
		ExecutorDefectTypes.ExecutorStartDefect,
		actionId,
		entity,
		actionData,
		services
	)
	if not startResult.success then
		return startResult
	end

	local values = startResult.value
	return Ok({
		Success = not not values[1],
		FailureReason = values[2],
	})
end

function ExecutorBoundary.TryTick(
	executor: TExecutor,
	actionId: string,
	entity: number,
	deltaTime: number,
	services: TExecutorServices
): Result.Result<string>
	local tickResult = _invokeExecutorMethod(
		executor,
		"Tick",
		ExecutorDefectTypes.ExecutorTickDefect,
		actionId,
		entity,
		deltaTime,
		services
	)
	if not tickResult.success then
		return tickResult
	end

	return Ok(tickResult.value[1])
end

function ExecutorBoundary.TryCancel(
	executor: TExecutor,
	actionId: string,
	entity: number,
	services: TExecutorServices
): Result.Result<boolean>
	local cancelResult =
		_invokeExecutorMethod(executor, "Cancel", ExecutorDefectTypes.ExecutorCancelDefect, actionId, entity, services)
	if not cancelResult.success then
		return cancelResult
	end

	return Ok(true)
end

function ExecutorBoundary.TryComplete(
	executor: TExecutor,
	actionId: string,
	entity: number,
	services: TExecutorServices
): Result.Result<boolean>
	local completeResult = _invokeExecutorMethod(
		executor,
		"Complete",
		ExecutorDefectTypes.ExecutorCompleteDefect,
		actionId,
		entity,
		services
	)
	if not completeResult.success then
		return completeResult
	end

	return Ok(true)
end

return table.freeze(ExecutorBoundary)
