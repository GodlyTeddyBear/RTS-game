--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Parallelizer = require(ReplicatedStorage.Packages.Parallelizer)
local Promise = require(ReplicatedStorage.Packages.Promise)

local Types = require(script.Types)
local Validation = require(script.Validation)

export type TFieldType = Types.TFieldType
export type TResultField = Types.TResultField
export type TOperationDefinition = Types.TOperationDefinition
export type TParallelQueryConfig = Types.TParallelQueryConfig
export type TParallelQueryError = Types.TParallelQueryError
export type TRunRequest = Types.TRunRequest
export type TParallelQueryRunner = Types.TParallelQueryRunner

type TDispatchHandle = Types.TDispatchHandle
type TRegisteredOperation = Types.TRegisteredOperation

type TFailureReport = {
	TaskId: number,
	Message: string,
	Traceback: string?,
}

local WORKER_SCRIPT_NAME = "Worker"
local WORKER_BOOTSTRAP_MODULE_NAME = "WorkerBootstrap"
local OPERATION_CLONES_FOLDER_NAME = "Operations"

--[=[
    @class ParallelQueryPackage
    Managed server-only actor runner that wraps `Parallelizer` with operation modules and decoded row results.
    @server
]=]
local ParallelQuery = {}
ParallelQuery.__index = ParallelQuery

local function _CloneWorkerTemplate(operationModules: { ModuleScript }): Script
	local workerTemplate = script:FindFirstChild(WORKER_SCRIPT_NAME)
	assert(workerTemplate ~= nil and workerTemplate:IsA("Script"), "ParallelQuery is missing its worker template")
	local workerBootstrapModule = script:FindFirstChild(WORKER_BOOTSTRAP_MODULE_NAME)
	assert(workerBootstrapModule ~= nil and workerBootstrapModule:IsA("ModuleScript"), "ParallelQuery is missing its worker bootstrap module")

	local clonedWorker = workerTemplate:Clone()
	workerBootstrapModule:Clone().Parent = clonedWorker
	local operationsFolder = Instance.new("Folder")
	operationsFolder.Name = OPERATION_CLONES_FOLDER_NAME
	operationsFolder.Parent = clonedWorker

	for _, operationModule in ipairs(operationModules) do
		local clone = operationModule:Clone()
		clone.Parent = operationsFolder
	end

	return clonedWorker
end

local function _CreateActorStorage(name: string, actorParent: Instance?): Folder
	if actorParent ~= nil then
		assert(actorParent:IsA("Instance"), "ParallelQuery ActorParent must be an Instance")

		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = actorParent
		return folder
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = ServerScriptService
	return folder
end

local function _ComputeBatchSize(workCount: number, actorCount: number, requestedBatchSize: number?): number
	if requestedBatchSize ~= nil then
		return math.max(1, requestedBatchSize)
	end

	return math.max(1, math.ceil(workCount / actorCount))
end

local function _BuildRuntimeName(name: string?): string
	if name ~= nil then
		return name
	end

	return ("ParallelQuery_%s"):format(HttpService:GenerateGUID(false))
end

local function _BuildDecodedRows(schema: { TResultField }, flattenedResults: { any }, workCount: number): { [string]: any }
	local fieldCount = #schema
	local rows = table.create(workCount)

	for rowIndex = 1, workCount do
		local row = {}
		local flatStart = (rowIndex - 1) * fieldCount

		for fieldIndex, field in ipairs(schema) do
			row[field.Name] = flattenedResults[flatStart + fieldIndex]
		end

		rows[rowIndex] = row
	end

	return rows
end

local function _RequireOperationDefinitions(operationModules: { ModuleScript }): { [string]: TOperationDefinition }
	local definitions = {}

	for _, operationModule in ipairs(operationModules) do
		local definition = require(operationModule) :: TOperationDefinition
		Validation.AssertOperationModule(operationModule, definition)
		Validation.AssertSchema(definition.ResultSchema, definition.Name)
		assert(definitions[definition.Name] == nil, (`ParallelQuery has duplicate operation name "{definition.Name}"`))
		definitions[definition.Name] = definition
	end

	return definitions
end

local function _BuildWorkerError(operationName: string, failureReports: { TFailureReport }): TParallelQueryError
	local taskIds = table.create(#failureReports)
	for index, failureReport in ipairs(failureReports) do
		taskIds[index] = failureReport.TaskId
	end

	local firstFailure = failureReports[1]
	local message = if #failureReports == 1
		then firstFailure.Message
		else (`ParallelQuery operation "{operationName}" failed in {#failureReports} tasks; first failure: {firstFailure.Message}`)

	return {
		Kind = "WorkerError",
		OperationName = operationName,
		Message = message,
		TaskIds = taskIds,
		Traceback = firstFailure.Traceback,
	}
end

function ParallelQuery:_IncrementActiveRun(operationName: string)
	local currentCount = self._activeRunCounts[operationName] or 0
	self._activeRunCounts[operationName] = currentCount + 1
end

function ParallelQuery:_DecrementActiveRun(operationName: string)
	local currentCount = self._activeRunCounts[operationName]
	if currentCount == nil then
		return
	end

	if currentCount <= 1 then
		self._activeRunCounts[operationName] = nil
		return
	end

	self._activeRunCounts[operationName] = currentCount - 1
end

--[=[
    Creates a managed `ParallelQuery` runner and registers every supplied operation module.
    @within ParallelQueryPackage
    @param config TParallelQueryConfig -- Runner configuration.
    @return TParallelQueryRunner -- New managed runner instance.
]=]
function ParallelQuery.new(config: TParallelQueryConfig): TParallelQueryRunner
	Validation.AssertConfig(config)

	local definitions = _RequireOperationDefinitions(config.Operations)
	local runtimeName = _BuildRuntimeName(config.Name)
	local actorStorage = _CreateActorStorage(runtimeName, config.ActorParent)

	local workerTemplate = _CloneWorkerTemplate(config.Operations)
	local coordinator = Parallelizer.CreateTaskCoordinator(workerTemplate, actorStorage, config.ActorCount)
	workerTemplate:Destroy()

	local self = setmetatable({}, ParallelQuery)
	self._name = runtimeName
	self._actorCount = config.ActorCount
	self._actorStorage = actorStorage
	self._coordinator = coordinator
	self._operations = {}
	self._activeRunCounts = {}
	self._destroyed = false

	for _, operationModule in ipairs(config.Operations) do
		local definition = definitions[(require(operationModule) :: TOperationDefinition).Name]
		local registeredOperation = {
			CacheLocalMemory = definition.CacheLocalMemory == true,
			Schema = definition.ResultSchema,
			TaskObject = coordinator:DefineTask(definition.Name, {
				packet = Validation.BuildPacketDefinition(definition.ResultSchema),
				localMemory = definition.InitialLocalMemory,
			}),
			LocalMemory = definition.InitialLocalMemory,
		}

		self._operations[definition.Name] = registeredOperation
	end

	return self :: any
end

--[=[
    Updates the cached shared memory for one operation across all worker actors.
    @within ParallelQueryPackage
    @param operationName string -- Registered operation name.
    @param sharedMemory SharedTable -- SharedTable broadcast to each worker clone.
]=]
function ParallelQuery:SetLocalMemory(operationName: string, sharedMemory: SharedTable)
	self:_AssertAlive()

	local operation = self._operations[operationName]
	assert(operation ~= nil, (`ParallelQuery operation "{operationName}" is not registered`))
	assert(operation.CacheLocalMemory, (`ParallelQuery operation "{operationName}" did not enable CacheLocalMemory`))
	assert((self._activeRunCounts[operationName] or 0) == 0, (`ParallelQuery:SetLocalMemory("{operationName}") cannot run while that operation is in flight`))
	Validation.AssertSharedMemory(sharedMemory, operationName)

	operation.LocalMemory = sharedMemory
	self._coordinator:SetTaskLocalMemory(operation.TaskObject, sharedMemory)
end

--[=[
    Dispatches one registered operation and decodes the flat callback payload into ordered row tables.
    @within ParallelQueryPackage
    @param operationName string -- Registered operation name.
    @param request TRunRequest -- Dispatch options for work count, batching, arguments, and timeout.
    @param onComplete function -- Completion callback that receives decoded row tables or a structured error.
]=]
function ParallelQuery:Run(
	operationName: string,
	request: TRunRequest,
	onComplete: ({ [string]: any }?, TParallelQueryError?) -> ()
)
	self:_AssertAlive()

	local operation = self._operations[operationName]
	assert(operation ~= nil, (`ParallelQuery operation "{operationName}" is not registered`))
	assert(type(onComplete) == "function", (`ParallelQuery:Run("{operationName}") requires an onComplete callback`))
	Validation.AssertRunRequest(request, operationName)

	local workCount = request.WorkCount
	if workCount == 0 then
		onComplete({}, nil)
		return
	end

	local argumentsList = if request.Arguments ~= nil then request.Arguments else {}
	Validation.AssertArguments(argumentsList, operationName)

	if operation.CacheLocalMemory and operation.LocalMemory == nil then
		error((`ParallelQuery operation "{operationName}" requires local memory before Run can be called`))
	end

	local batchSize = _ComputeBatchSize(workCount, self._actorCount, request.BatchSize)
	local paddedWorkCount = math.ceil(workCount / batchSize) * batchSize
	local failureReports = {} :: { TFailureReport }
	local failureBindable = Instance.new("BindableEvent")
	local failureConnection = failureBindable.Event:Connect(function(taskId: number, message: string, tracebackMessage: string?)
		table.insert(failureReports, {
			TaskId = taskId,
			Message = message,
			Traceback = tracebackMessage,
		})
	end)

	local settled = false
	local cleanedUp = false
	local dispatchHandle: TDispatchHandle? = nil
	local timeoutThread: thread? = nil

	self:_IncrementActiveRun(operationName)

	local function cleanup()
		if cleanedUp then
			return
		end

		cleanedUp = true

		if timeoutThread ~= nil then
			task.cancel(timeoutThread)
			timeoutThread = nil
		end

		failureConnection:Disconnect()
		self:_DecrementActiveRun(operationName)
	end

	local function settle(rows: { [string]: any }?, err: TParallelQueryError?, cancelDispatch: boolean?)
		if settled then
			return
		end

		settled = true

		if cancelDispatch == true and dispatchHandle ~= nil then
			dispatchHandle:Cancel()
		end

		cleanup()
		onComplete(rows, err)
	end

	if request.TimeoutSeconds ~= nil then
		timeoutThread = task.delay(request.TimeoutSeconds, function()
			settle(nil, {
				Kind = "Timeout",
				OperationName = operationName,
				Message = (`ParallelQuery operation "{operationName}" timed out after {request.TimeoutSeconds} seconds`),
				TimeoutSeconds = request.TimeoutSeconds,
			}, true)
		end)
	end

	dispatchHandle = self._coordinator:DispatchTask(operation.TaskObject, paddedWorkCount, batchSize, function(flattenedResults)
		task.defer(function()
			if settled then
				return
			end

			if #failureReports > 0 then
				settle(nil, _BuildWorkerError(operationName, failureReports), false)
				return
			end

			local rows = _BuildDecodedRows(operation.Schema, flattenedResults, workCount)
			settle(rows, nil, false)
		end)
	end, false, workCount, failureBindable, table.unpack(argumentsList))
end

function ParallelQuery:RunAsync(operationName: string, request: TRunRequest)
	self:_AssertAlive()

	return Promise.new(function(resolve, reject)
		self:Run(operationName, request, function(rows, err)
			if err ~= nil then
				reject(err)
				return
			end

			resolve(rows)
		end)
	end)
end

--[=[
    Destroys the managed actors, task coordinator, and owned actor storage folder.
    @within ParallelQueryPackage
]=]
function ParallelQuery:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._coordinator:Destroy()
	self._actorStorage:Destroy()

	table.clear(self._operations)
	table.clear(self._activeRunCounts)
end

function ParallelQuery:_AssertAlive()
	assert(not self._destroyed, "ParallelQuery runner has already been destroyed")
end

return table.freeze(ParallelQuery)
