--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Parallelizer = require(ReplicatedStorage.Utilities.Parallelizer)
local Promise = require(ReplicatedStorage.Packages.Promise)

local Field = require(script.Field)
local ManagedAsync = require(script.ManagedAsync)
local ManagedJob = require(script.ManagedJob)
local ManagedJobPolicies = require(script.ManagedJobPolicies)
local Operation = require(script.Operation)
local Profiling = require(script.Profiling)
local ResultApplication = require(script.ResultApplication)
local ResultReduction = require(script.ResultReduction)
local RowDefaults = require(script.RowDefaults)
local SharedMemory = require(script.SharedMemory)
local SharedMemoryAuthoring = require(script.SharedMemoryAuthoring)
local Types = require(script.Types)
local Validation = require(script.Validation)
local ValidationHelpers = require(script.ValidationHelpers)

export type TFieldType = Types.TFieldType
export type TResultField = Types.TResultField
export type TOperationDefinition = Types.TOperationDefinition
export type TStaticOperationDefinition = Types.TStaticOperationDefinition
export type TParallelQueryConfig = Types.TParallelQueryConfig
export type TParallelQueryError = Types.TParallelQueryError
export type TRunRequest = Types.TRunRequest
export type TParallelQueryRunner = Types.TParallelQueryRunner
export type TSharedMemoryScalar = Types.TSharedMemoryScalar
export type TSharedMemoryArray = Types.TSharedMemoryArray
export type TSharedMemoryFieldValue = Types.TSharedMemoryFieldValue
export type TSharedMemoryFieldMap = Types.TSharedMemoryFieldMap
export type TSharedMemorySnapshotBuilder = Types.TSharedMemorySnapshotBuilder
export type TManagedAsyncResult = Types.TManagedAsyncResult
export type TManagedAsyncState = Types.TManagedAsyncState
export type TManagedDispatchStatus = Types.TManagedDispatchStatus
export type TManagedCompletionStatus = Types.TManagedCompletionStatus
export type TManagedConsumeStatus = Types.TManagedConsumeStatus
export type TManagedJobPolicyPreset = Types.TManagedJobPolicyPreset
export type TManagedJobPolicyConfig = Types.TManagedJobPolicyConfig
export type TManagedJobDispatchStatus = Types.TManagedJobDispatchStatus
export type TManagedJobConfig = Types.TManagedJobConfig
export type TManagedJobResult = Types.TManagedJobResult
export type TManagedJob = Types.TManagedJob
export type TRowFieldValidationResult = Types.TRowFieldValidationResult
export type TSchemaRowValidationMode = Types.TSchemaRowValidationMode
export type TSchemaRowValidationResult = Types.TSchemaRowValidationResult
export type TSchemaRowsValidationResult = Types.TSchemaRowsValidationResult
export type TMemoryFieldValidationResult = Types.TMemoryFieldValidationResult
export type TRowApplicationResult = Types.TRowApplicationResult
export type TReductionSummary = Types.TReductionSummary
export type TParallelQueryProfileCounters = Types.TParallelQueryProfileCounters
export type TParallelQueryOperationProfileSnapshot = Types.TParallelQueryOperationProfileSnapshot
export type TParallelQueryProfileSnapshot = Types.TParallelQueryProfileSnapshot
export type TManagedJobProfileSnapshot = Types.TManagedJobProfileSnapshot

type TDispatchHandle = Types.TDispatchHandle
type TManagedJobConfig = Types.TManagedJobConfig
type TManagedJob = Types.TManagedJob
type TRegisteredOperation = Types.TRegisteredOperation

type TFailureReport = {
	TaskId: number,
	Message: string,
	Traceback: string?,
}

local WORKER_SCRIPT_NAME = "Worker"
local WORKER_BOOTSTRAP_MODULE_NAME = "WorkerBootstrap"
local OPERATION_CLONES_FOLDER_NAME = "Operations"
local OPERATION_CONFIG_JSON_ATTRIBUTE_NAME = "ParallelQueryOperationConfigJson"

--[=[
    @class ParallelQueryPackage
    Managed server-only actor runner that wraps `Parallelizer` with operation modules and decoded row results.
    @server
]=]
local ParallelQuery = {}
ParallelQuery.__index = ParallelQuery

--[=[
	@prop Field table
	@within ParallelQueryPackage
	Schema field constructors for authoring operation result schemas.
]=]
ParallelQuery.Field = Field

--[=[
	@prop RowDefaults table
	@within ParallelQueryPackage
	Default-row builders for schema-backed operation rows.
]=]
ParallelQuery.RowDefaults = RowDefaults

--[=[
	@prop Operation table
	@within ParallelQueryPackage
	Light helpers for defining static-schema operations and cached-memory operation modules.
	Use raw operation tables when the schema is dynamic.
	Use operation local memory for shared cached payloads and request arguments for per-dispatch scalar inputs.
]=]
ParallelQuery.Operation = Operation

--[=[
	@prop ValidationHelpers table
	@within ParallelQueryPackage
	Structural row and shared-memory validation helpers for worker output and cached local memory.
	These helpers only validate shape and required fields; domain correctness still belongs to the caller.
]=]
ParallelQuery.ValidationHelpers = ValidationHelpers

--[=[
	@prop ResultApplication table
	@within ParallelQueryPackage
	Helpers for safe row iteration, indexed row resolution, and result-application summaries.
	Use this with `ValidationHelpers` when you want canonical "validate -> resolve -> apply" row handling.
]=]
ParallelQuery.ResultApplication = ResultApplication

--[=[
	@prop ResultReduction table
	@within ParallelQueryPackage
	Generic reducers for building lookup maps, grouped rows, pair aggregates, and vector accumulations from decoded rows.
	Use this after validation when the caller wants derived data instead of immediate side effects.
]=]
ParallelQuery.ResultReduction = ResultReduction

--[=[
	@prop SharedMemoryAuthoring table
	@within ParallelQueryPackage
	Helpers for building named array-backed snapshot fields before passing them into `BuildSharedMemory`.
	Use this for movement-style "fill arrays in a loop, then pack one root field map" workflows.
]=]
ParallelQuery.SharedMemoryAuthoring = SharedMemoryAuthoring

--[=[
	@prop ManagedJobPolicies table
	@within ParallelQueryPackage
	Named managed-job policy presets.
	Use `StrictFreshOnly` for only fresh completions, `KeepLastGood` to reuse the latest successful rows on failure,
	and `ApplyFreshOrMarkFallback` to surface fallback markers without replaying prior rows.
]=]
ParallelQuery.ManagedJobPolicies = ManagedJobPolicies

--[=[
	Builds a SharedTable from a root field map of scalars and array-like child tables.
	@within ParallelQueryPackage
	@param fields { [string]: TSharedMemoryFieldValue } -- Shared memory fields to copy into a new SharedTable.
	@return SharedTable -- Newly constructed shared memory payload.
]=]
function ParallelQuery.BuildSharedMemory(fields: { [string]: Types.TSharedMemoryFieldValue }): SharedTable
	return SharedMemory.Build(fields)
end

--[=[
	Creates a reusable async state record for callers that want low-level request bookkeeping.
	@within ParallelQueryPackage
	@return TManagedAsyncState -- Fresh async state with no in-flight or completed result.
]=]
function ParallelQuery.CreateManagedAsyncState(): Types.TManagedAsyncState
	return ManagedAsync.CreateState()
end

function ParallelQuery.ResetManagedAsyncState(state: Types.TManagedAsyncState)
	ManagedAsync.ResetState(state)
end

function ParallelQuery.ExpireManagedInFlightRequest(
	state: Types.TManagedAsyncState,
	maxInFlightSeconds: number,
	nowClock: number?
): boolean
	return ManagedAsync.ExpireInFlightRequest(state, maxInFlightSeconds, nowClock)
end

function ParallelQuery.HasManagedInFlightRequest(
	state: Types.TManagedAsyncState,
	maxInFlightSeconds: number?,
	nowClock: number?
): boolean
	return ManagedAsync.HasInFlightRequest(state, maxInFlightSeconds, nowClock)
end

function ParallelQuery.BeginManagedRequest(
	state: Types.TManagedAsyncState,
	sessionToken: any?,
	nowClock: number?,
	maxInFlightSeconds: number?
): (Types.TManagedDispatchStatus, number?)
	return ManagedAsync.BeginRequest(state, sessionToken, nowClock, maxInFlightSeconds)
end

function ParallelQuery.CompleteManagedRequest(
	state: Types.TManagedAsyncState,
	result: Types.TManagedAsyncResult
): Types.TManagedCompletionStatus
	return ManagedAsync.CompleteRequest(state, result)
end

function ParallelQuery.ConsumeLatestManagedResult(
	state: Types.TManagedAsyncState,
	currentSessionToken: any?
): (Types.TManagedAsyncResult?, Types.TManagedConsumeStatus)
	return ManagedAsync.ConsumeLatestResult(state, currentSessionToken)
end

local function _CloneWorkerTemplate(
	operationModules: { ModuleScript },
	operationConfigsByName: { [string]: any }?
): Script
	local workerTemplate = script:FindFirstChild(WORKER_SCRIPT_NAME)
	assert(workerTemplate ~= nil and workerTemplate:IsA("Script"), "ParallelQuery is missing its worker template")
	local workerBootstrapModule = script:FindFirstChild(WORKER_BOOTSTRAP_MODULE_NAME)
	assert(
		workerBootstrapModule ~= nil and workerBootstrapModule:IsA("ModuleScript"),
		"ParallelQuery is missing its worker bootstrap module"
	)

	local clonedWorker = workerTemplate:Clone()
	workerBootstrapModule:Clone().Parent = clonedWorker
	local operationsFolder = Instance.new("Folder")
	operationsFolder.Name = OPERATION_CLONES_FOLDER_NAME
	operationsFolder.Parent = clonedWorker

	for _, operationModule in ipairs(operationModules) do
		local clone = operationModule:Clone()
		local definition = require(operationModule) :: TOperationDefinition
		local operationConfig = if operationConfigsByName ~= nil then operationConfigsByName[definition.Name] else nil
		if operationConfig ~= nil then
			Validation.AssertOperationConfigEncodable(definition.Name, operationConfig)
			clone:SetAttribute(OPERATION_CONFIG_JSON_ATTRIBUTE_NAME, HttpService:JSONEncode(operationConfig))
		end
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

local function _BuildDecodedRows(
	schema: { TResultField },
	flattenedResults: { any },
	workCount: number
): { [string]: any }
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

local function _RequireOperationDefinitions(
	operationModules: { ModuleScript },
	operationConfigsByName: { [string]: any }?
): { [string]: TOperationDefinition }
	local definitions = {}

	for _, operationModule in ipairs(operationModules) do
		local definition = require(operationModule) :: TOperationDefinition
		Validation.AssertOperationModule(operationModule, definition)
		local operationConfig = if operationConfigsByName ~= nil then operationConfigsByName[definition.Name] else nil
		local resolvedSchema = Validation.ResolveSchema(definition, operationConfig)
		Validation.AssertSchema(resolvedSchema, definition.Name)
		local resolvedDefinition = table.clone(definition)
		resolvedDefinition.ResultSchema = resolvedSchema
		assert(definitions[definition.Name] == nil, `ParallelQuery has duplicate operation name "{definition.Name}"`)
		definitions[definition.Name] = resolvedDefinition
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
		else `ParallelQuery operation "{operationName}" failed in {#failureReports} tasks; first failure: {firstFailure.Message}`

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

	local operationConfigsByName = config.OperationConfigs
	local definitions = _RequireOperationDefinitions(config.Operations, operationConfigsByName)
	local runtimeName = _BuildRuntimeName(config.Name)
	local actorStorage = _CreateActorStorage(runtimeName, config.ActorParent)

	local workerTemplate = _CloneWorkerTemplate(config.Operations, operationConfigsByName)
	local coordinator = Parallelizer.CreateTaskCoordinator(workerTemplate, actorStorage, config.ActorCount)
	workerTemplate:Destroy()

	local self = setmetatable({}, ParallelQuery)
	self._name = runtimeName
	self._actorCount = config.ActorCount
	self._actorStorage = actorStorage
	self._coordinator = coordinator
	self._operations = {}
	self._activeRunCounts = {}
	self._managedJobs = {}
	self._profile = Profiling.CreateRunnerProfile(runtimeName)
	self._destroyed = false

	for _, operationModule in ipairs(config.Operations) do
		local definitionName = (require(operationModule) :: TOperationDefinition).Name
		local definition = definitions[definitionName]
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
	Creates an operation-bound managed job on this runner for ergonomic dispatch and polling.
	Use `RunAsync` directly when the caller already owns its async state or only needs one-shot dispatch.
	Use managed jobs for repeated frame-based work where stale-result rejection, timeout expiry, and policy presets should stay inside the utility.
	@within ParallelQueryPackage
	@param config TManagedJobConfig -- Managed job configuration for one registered operation.
	@return TManagedJob -- Operation-bound job object tied to this runner.
]=]
function ParallelQuery:CreateManagedJob(config: TManagedJobConfig): TManagedJob
	self:_AssertAlive()
	return ManagedJob.new(self :: any, config)
end

function ParallelQuery:GetProfileSnapshot(): Types.TParallelQueryProfileSnapshot?
	self:_AssertAlive()
	return Profiling.GetRunnerSnapshot(self._profile)
end

function ParallelQuery:EmitProfileSummary(force: boolean?)
	self:_AssertAlive()
	Profiling.EmitRunnerSummary(self._profile, force)
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
	assert(operation ~= nil, `ParallelQuery operation "{operationName}" is not registered`)
	assert(operation.CacheLocalMemory, `ParallelQuery operation "{operationName}" did not enable CacheLocalMemory`)
	assert(
		(self._activeRunCounts[operationName] or 0) == 0,
		`ParallelQuery:SetLocalMemory("{operationName}") cannot run while that operation is in flight`
	)
	Validation.AssertSharedMemory(sharedMemory, operationName)

	operation.LocalMemory = sharedMemory
	self._coordinator:SetTaskLocalMemory(operation.TaskObject, sharedMemory)
end

--[=[
    Dispatches one registered operation and decodes the flat callback payload into ordered row tables.
    This is the low-level callback API. Prefer `RunAsync` when the caller can use Promise composition or `:await()`.
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
	local closeRunSetupProfile = Profiling.BeginOperationScope(self._profile, operationName, "Run")

	local operation = self._operations[operationName]
	assert(operation ~= nil, `ParallelQuery operation "{operationName}" is not registered`)
	assert(type(onComplete) == "function", `ParallelQuery:Run("{operationName}") requires an onComplete callback`)
	Validation.AssertRunRequest(request, operationName)

	local workCount = request.WorkCount
	if workCount == 0 then
		closeRunSetupProfile()
		onComplete({}, nil)
		return
	end

	local argumentsList = if request.Arguments ~= nil then request.Arguments else {}
	Validation.AssertArguments(argumentsList, operationName)

	if operation.CacheLocalMemory and operation.LocalMemory == nil then
		error(`ParallelQuery operation "{operationName}" requires local memory before Run can be called`)
	end

	local batchSize = _ComputeBatchSize(workCount, self._actorCount, request.BatchSize)
	local paddedWorkCount = math.ceil(workCount / batchSize) * batchSize
	local failureReports = {} :: { TFailureReport }
	local failureBindable = Instance.new("BindableEvent")
	local failureConnection = failureBindable.Event:Connect(
		function(taskId: number, message: string, tracebackMessage: string?)
			table.insert(failureReports, {
				TaskId = taskId,
				Message = message,
				Traceback = tracebackMessage,
			})
		end
	)

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
		failureBindable:Destroy()
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
			local closeTimeoutProfile = Profiling.BeginOperationScope(self._profile, operationName, "Timeout")
			settle(nil, {
				Kind = "Timeout",
				OperationName = operationName,
				Message = `ParallelQuery operation "{operationName}" timed out after {request.TimeoutSeconds} seconds`,
				TimeoutSeconds = request.TimeoutSeconds,
			}, true)
			closeTimeoutProfile()
		end)
	end

	dispatchHandle = self._coordinator:DispatchTask(
		operation.TaskObject,
		paddedWorkCount,
		batchSize,
		function(flattenedResults)
			task.defer(function()
				local closeCompleteProfile = Profiling.BeginOperationScope(self._profile, operationName, "Complete")
				if settled then
					closeCompleteProfile()
					return
				end

				if #failureReports > 0 then
					settle(nil, _BuildWorkerError(operationName, failureReports), false)
					closeCompleteProfile()
					return
				end

				local rows = _BuildDecodedRows(operation.Schema, flattenedResults, workCount)
				settle(rows, nil, false)
				closeCompleteProfile()
			end)
		end,
		false,
		workCount,
		failureBindable,
		table.unpack(argumentsList)
	)
	closeRunSetupProfile()
end

--[=[
    Dispatches one registered operation and resolves with decoded row tables.
    Rejects with the same structured error payload that `Run` passes to `onComplete`.
    This is the canonical caller-facing API for Promise users.
    Use cached local memory for shared array payloads that should be reused by all worker tasks in the run.
    Use request arguments only for per-dispatch scalar inputs that do not need SharedTable packing.
    @within ParallelQueryPackage
    @param operationName string -- Registered operation name.
    @param request TRunRequest -- Dispatch options for work count, batching, arguments, and timeout.
    @return Promise -- Promise that resolves with decoded row tables or rejects with `TParallelQueryError`.
]=]
function ParallelQuery:RunAsync(operationName: string, request: TRunRequest): typeof(Promise.new(function() end))
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
	local managedJobs = {}
	for job in self._managedJobs do
		table.insert(managedJobs, job)
	end
	for _, job in ipairs(managedJobs) do
		job:Destroy()
	end

	self._coordinator:Destroy()
	self._actorStorage:Destroy()

	table.clear(self._managedJobs)
	table.clear(self._operations)
	table.clear(self._activeRunCounts)
end

function ParallelQuery:_AssertAlive()
	assert(not self._destroyed, "ParallelQuery runner has already been destroyed")
end

return table.freeze(ParallelQuery)
