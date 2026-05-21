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

local function _createInvocationData(actionId: string, entity: number, methodName: string): { [string]: any }
	return {
		ActionId = actionId,
		Entity = entity,
		Method = methodName,
	}
end

local function _invokeStart(
	executor: TExecutor,
	actionId: string,
	entity: number,
	actionData: any?,
	services: TExecutorServices
): Result.Result<TStartInvocation>
	local invocationData = _createInvocationData(actionId, entity, "Start")
	local didSucceed, success, failureReason = xpcall(function()
		return executor:Start(entity, actionData, services)
	end, function(thrown)
		return _createDefect(
			ExecutorDefectTypes.ExecutorStartDefect,
			tostring(thrown),
			invocationData,
			debug.traceback(nil, 2)
		)
	end)

	if not didSucceed then
		return success
	end

	return Ok({
		Success = not not success,
		FailureReason = failureReason,
	})
end

local function _invokeTick(
	executor: TExecutor,
	actionId: string,
	entity: number,
	deltaTime: number,
	services: TExecutorServices
): Result.Result<string>
	local invocationData = _createInvocationData(actionId, entity, "Tick")
	local didSucceed, tickStatus = xpcall(function()
		return executor:Tick(entity, deltaTime, services)
	end, function(thrown)
		return _createDefect(
			ExecutorDefectTypes.ExecutorTickDefect,
			tostring(thrown),
			invocationData,
			debug.traceback(nil, 2)
		)
	end)

	if not didSucceed then
		return tickStatus
	end

	return Ok(tickStatus)
end

local function _invokeVoidMethod(
	executor: TExecutor,
	methodName: string,
	defectType: string,
	actionId: string,
	entity: number,
	services: TExecutorServices
): Result.Result<boolean>
	local invocationData = _createInvocationData(actionId, entity, methodName)
	local didSucceed, defect = xpcall(function()
		(executor :: any)[methodName](executor, entity, services)
		return nil
	end, function(thrown)
		return _createDefect(defectType, tostring(thrown), invocationData, debug.traceback(nil, 2))
	end)

	if not didSucceed then
		return defect
	end

	return Ok(true)
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
	return _invokeStart(executor, actionId, entity, actionData, services)
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
	return _invokeTick(executor, actionId, entity, deltaTime, services)
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
	return _invokeVoidMethod(executor, "Cancel", ExecutorDefectTypes.ExecutorCancelDefect, actionId, entity, services)
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
	return _invokeVoidMethod(executor, "Complete", ExecutorDefectTypes.ExecutorCompleteDefect, actionId, entity, services)
end

--[=[
	Invokes an executor death method and converts thrown defects into a structured result.
	@within ExecutorBoundary
	@param executor TExecutor -- Executor instance to invoke
	@param actionId string -- Action id used for defect metadata
	@param entity number -- Runtime entity id forwarded to the executor
	@param services TExecutorServices -- Executor service bag forwarded to the executor
	@return Result<boolean> -- `true` when death handling succeeds or a defect
]=]
function ExecutorBoundary.TryDeath(
	executor: TExecutor,
	actionId: string,
	entity: number,
	services: TExecutorServices
): Result.Result<boolean>
	return _invokeVoidMethod(executor, "Death", ExecutorDefectTypes.ExecutorDeathDefect, actionId, entity, services)
end

return table.freeze(ExecutorBoundary)
