--!strict

--[=[
	@class ExecutorBoundary
	Wraps executor method calls so thrown defects become structured runtime results.
	@server
	@client
]=]

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

-- Build a defect payload that preserves executor metadata and traceback context.
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

-- Invoke a named executor method behind xpcall so thrown errors stay inside the runtime boundary.
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

--[=[
	Invokes an executor start method and converts thrown defects into a structured result.
	@within ExecutorBoundary
	@param executor TExecutor -- Executor instance to invoke
	@param actionId string -- Action id used for defect metadata
	@param entity number -- Runtime entity id forwarded to the executor
	@param actionData any? -- Pending action data forwarded to `Start`
	@param services TExecutorServices -- Executor service bag forwarded to the executor
	@return Result<TStartInvocation> -- Structured invocation result or a defect
]=]
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

--[=[
	Invokes an executor tick method and converts thrown defects into a structured result.
	@within ExecutorBoundary
	@param executor TExecutor -- Executor instance to invoke
	@param actionId string -- Action id used for defect metadata
	@param entity number -- Runtime entity id forwarded to the executor
	@param deltaTime number -- Frame delta forwarded to `Tick`
	@param services TExecutorServices -- Executor service bag forwarded to the executor
	@return Result<string> -- First returned tick status or a defect
]=]
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

--[=[
	Invokes an executor cancel method and converts thrown defects into a structured result.
	@within ExecutorBoundary
	@param executor TExecutor -- Executor instance to invoke
	@param actionId string -- Action id used for defect metadata
	@param entity number -- Runtime entity id forwarded to the executor
	@param services TExecutorServices -- Executor service bag forwarded to the executor
	@return Result<boolean> -- `true` when cancel completes or a defect
]=]
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

--[=[
	Invokes an executor complete method and converts thrown defects into a structured result.
	@within ExecutorBoundary
	@param executor TExecutor -- Executor instance to invoke
	@param actionId string -- Action id used for defect metadata
	@param entity number -- Runtime entity id forwarded to the executor
	@param services TExecutorServices -- Executor service bag forwarded to the executor
	@return Result<boolean> -- `true` when complete succeeds or a defect
]=]
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
