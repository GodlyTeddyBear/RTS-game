--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelActors = require(ReplicatedStorage.Utilities.ParallelActors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Compiler = require(script.Compiler)
local ManagedJob = require(script.ManagedJob)
local ManagedJobPolicies = require(script.ManagedJobPolicies)
local ResultApplication = require(script.ResultApplication)
local RunHandle = require(script.RunHandle)
local Types = require(script.Types)
local Validation = require(script.Validation)
local ValidationHelpers = require(script.ValidationHelpers)

export type TResult<T> = Types.TResult<T>
export type TFieldType = Types.TFieldType
export type TResultField = Types.TResultField
export type TCompiledJob = Types.TCompiledJob
export type TDefineJobConfig = Types.TDefineJobConfig
export type TRunnerConfig = Types.TRunnerConfig
export type TRegisterJobConfig = Types.TRegisterJobConfig
export type TRunRequest = Types.TRunRequest
export type TRunOutput = Types.TRunOutput
export type TRunPromise = Types.TRunPromise
export type TManagedJobPolicyPreset = Types.TManagedJobPolicyPreset
export type TManagedJobConfig = Types.TManagedJobConfig
export type TManagedJobDispatchStatus = Types.TManagedJobDispatchStatus
export type TManagedJobStatus = Types.TManagedJobStatus
export type TManagedJobResult = Types.TManagedJobResult
export type TManagedJob = Types.TManagedJob
export type TSharedPacket = Types.TSharedPacket
export type TSharedCompiledHandle = Types.TSharedCompiledHandle
export type TPayloadSchemaDescriptor = Types.TPayloadSchemaDescriptor
export type TRowFieldValidationResult = Types.TRowFieldValidationResult
export type TSchemaRowValidationMode = Types.TSchemaRowValidationMode
export type TSchemaRowValidationResult = Types.TSchemaRowValidationResult
export type TSchemaRowsValidationResult = Types.TSchemaRowsValidationResult
export type TRowApplicationResult = Types.TRowApplicationResult
export type TRunnerRunHandle = Types.TRunnerRunHandle
export type TRunner = Types.TRunner

type TRegisteredJob = Types.TRegisteredJob
type TWorkplaceRunResult = Types.TWorkplaceRunResult

local Ok = Result.Ok
local Err = Result.Err

local ParallelRunner = {}
ParallelRunner.__index = ParallelRunner

ParallelRunner.Compiler = Compiler
ParallelRunner.Arg = Compiler.Arg
ParallelRunner.Result = Compiler.Result
ParallelRunner.ManagedJobPolicies = ManagedJobPolicies
ParallelRunner.ValidationHelpers = ValidationHelpers
ParallelRunner.ResultApplication = ResultApplication

local WORKER_ERROR_PATTERN = "^%[([^%]]+)%]%s+([^:]+):%s+(.*)$"

local function _BuildSetupError(errType: string, message: string, data: { [string]: any }?): TResult<any>
	return Err(errType, message, data)
end

local function _BuildDestroyedError(): TResult<any>
	return Err("ParallelRunnerDestroyed", "ParallelRunner has already been destroyed")
end

local function _ResolveLogicalWorkCount(registeredJob: TRegisteredJob, request: Types.TRunRequest): (number?, TResult<any>?)
	if request.LogicalWorkCount ~= nil then
		return request.LogicalWorkCount, nil
	end

	if registeredJob.DefaultLogicalWorkCount ~= nil then
		return registeredJob.DefaultLogicalWorkCount, nil
	end

	return nil, _BuildSetupError(
		"ParallelRunnerRunRequestError",
		`ParallelRunner:Run("{request.JobName}") requires LogicalWorkCount when no job default exists`,
		{
			JobName = request.JobName,
		}
	)
end

local function _ResolveBatchSize(self: any, registeredJob: TRegisteredJob, request: Types.TRunRequest): number?
	if request.BatchSize ~= nil then
		return request.BatchSize
	end

	if registeredJob.DefaultBatchSize ~= nil then
		return registeredJob.DefaultBatchSize
	end

	return self._defaultBatchSize
end

local function _ResolveSharedMemory(
	registeredJob: TRegisteredJob,
	request: Types.TRunRequest
): (SharedTable?, TResult<any>?)
	if registeredJob.SharedMemory ~= nil and request.SharedMemory ~= nil then
		return nil, _BuildSetupError(
			"ParallelRunnerSharedMemoryConflict",
			`ParallelRunner:Run("{request.JobName}") cannot combine registered SharedMemory with request SharedMemory`,
			{
				JobName = request.JobName,
			}
		)
	end

	if request.SharedMemory ~= nil then
		return request.SharedMemory, nil
	end

	return registeredJob.SharedMemory, nil
end

local function _ResolveWorkerPayloadBuffer(
	registeredJob: TRegisteredJob,
	request: Types.TRunRequest
): (buffer?, TResult<any>?)
	if request.WorkerPayload == nil then
		return registeredJob.WorkerPayloadBuffer, nil
	end

	local payloadCodec = registeredJob.PayloadCodec
	if payloadCodec == nil then
		return nil, _BuildSetupError(
			"ParallelRunnerWorkerPayloadSchemaMissing",
			`ParallelRunner:Run("{request.JobName}") cannot accept WorkerPayload because the job does not define PayloadSchema`,
			{
				JobName = request.JobName,
			}
		)
	end

	local workerPayloadBuffer, payloadEncodeError = payloadCodec:Encode(request.WorkerPayload)
	if workerPayloadBuffer == nil then
		return nil, _BuildSetupError(
			"ParallelRunnerWorkerPayloadEncodeError",
			`ParallelRunner:Run("{request.JobName}") failed to encode WorkerPayload`,
			{
				JobName = request.JobName,
				Cause = payloadEncodeError,
			}
		)
	end

	return workerPayloadBuffer, nil
end

local function _BuildRunFailureResult(workplaceRunResult: TWorkplaceRunResult): TResult<Types.TRunOutput>
	local causeMessage = if workplaceRunResult.FirstError ~= nil then workplaceRunResult.FirstError.Message else nil
	local workerErrorType = nil :: string?
	local workerErrorMessage = nil :: string?
	if causeMessage ~= nil then
		local parsedErrorType, _, parsedErrorMessage = string.match(causeMessage, WORKER_ERROR_PATTERN)
		workerErrorType = parsedErrorType
		workerErrorMessage = parsedErrorMessage
	end

	local errorData = {
		JobName = workplaceRunResult.JobName,
		RunId = workplaceRunResult.RunId,
		Cause = workplaceRunResult.FirstError,
		PartialRows = nil,
	}

	if workplaceRunResult.Status == "Cancelled" then
		return Err(
			"ParallelRunnerRunCancelled",
			`ParallelRunner run "{workplaceRunResult.JobName}" was cancelled`,
			errorData
		)
	end

	if workerErrorType ~= nil then
		return Err(
			workerErrorType,
			workerErrorMessage or (`ParallelRunner run "{workplaceRunResult.JobName}" failed in worker execution`),
			errorData
		)
	end

	return Err(
		"ParallelRunnerRunFailed",
		`ParallelRunner run "{workplaceRunResult.JobName}" failed`,
		errorData
	)
end

local function _BuildDecodeError(
	jobName: string,
	runId: number,
	shardIndex: number,
	decodeError: string
): TResult<Types.TRunOutput>
	return Err(
		"ParallelRunnerShardDecodeError",
		`ParallelRunner run "{jobName}" failed to decode shard #{shardIndex}`,
		{
			JobName = jobName,
			RunId = runId,
			ShardIndex = shardIndex,
			Cause = decodeError,
			PartialRows = nil,
		}
	)
end

local function _BuildMalformedShardError(jobName: string, runId: number, shardIndex: number): TResult<Types.TRunOutput>
	return Err(
		"ParallelRunnerMalformedShardOutput",
		`ParallelRunner run "{jobName}" decoded malformed shard #{shardIndex}`,
		{
			JobName = jobName,
			RunId = runId,
			ShardIndex = shardIndex,
			PartialRows = nil,
		}
	)
end

local function _BuildPromiseRejectedResult(jobName: string, runId: number, promiseError: any): TResult<Types.TRunOutput>
	return Err(
		"ParallelRunnerPromiseRejected",
		`ParallelRunner run "{jobName}" promise rejected unexpectedly`,
		{
			JobName = jobName,
			RunId = runId,
			Cause = promiseError,
			PartialRows = nil,
		}
	)
end

local function _MaterializeResult<T>(result: TResult<T>): { [string]: any }
	if result.success then
		return {
			_isResult = true,
			success = true,
			value = result.value,
		}
	end

	local resolvedError = result :: any
	return {
		_isResult = true,
		success = false,
		type = resolvedError.type,
		message = resolvedError.message,
		data = resolvedError.data,
		traceback = resolvedError.traceback,
		isDefect = resolvedError.isDefect,
	}
end

function ParallelRunner.DefineJob(config: TDefineJobConfig): TCompiledJob
	return Compiler.DefineJob(config)
end

function ParallelRunner.new(config: TRunnerConfig): TRunner
	local ok, workplaceOrError = pcall(function()
		Validation.AssertRunnerConfig(config :: any)

		local self = setmetatable({}, ParallelRunner)

		-- Variables
		self._name = config.Name or "ParallelRunner"
		self._defaultBatchSize = config.DefaultBatchSize
		self._registeredJobs = {} :: { [string]: TRegisteredJob }
		self._managedJobs = {}
		self._destroyed = false

		-- Build the underlying actor workplace once for this runner.
		self._workplace = ParallelActors.new({
			Name = self._name,
			ActorCount = config.ActorCount,
			DefaultBatchSize = config.DefaultBatchSize,
		})

		return self
	end)

	assert(ok, workplaceOrError)
	return workplaceOrError :: any
end

function ParallelRunner:RegisterJob(config: TRegisterJobConfig): TResult<boolean>
	if self._destroyed then
		return _BuildDestroyedError()
	end

	local ok, registerOrError = pcall(function()
		Validation.AssertJobRegistration(config :: any)

		local jobName = config.Job:GetName()
		if self._registeredJobs[jobName] ~= nil then
			return _BuildSetupError(
				"ParallelRunnerRegistrationError",
				`ParallelRunner:RegisterJob("{jobName}") cannot overwrite an existing job`,
				{
					JobName = jobName,
				}
			)
		end

		local workerExport = require(config.WorkerModule)
		if type(workerExport) ~= "table" then
			return _BuildSetupError(
				"ParallelRunnerWorkerModuleError",
				`ParallelRunner:RegisterJob("{jobName}") WorkerModule must return a table`,
				{
					JobName = jobName,
					WorkerModule = config.WorkerModule:GetFullName(),
				}
			)
		end

		if type((workerExport :: any).Execute) ~= "function" then
			return _BuildSetupError(
				"ParallelRunnerWorkerModuleError",
				`ParallelRunner:RegisterJob("{jobName}") WorkerModule must export Execute(request)`,
				{
					JobName = jobName,
					WorkerModule = config.WorkerModule:GetFullName(),
				}
			)
		end

		(self._workplace :: any):RegisterCompiledJob(config.Job, config.WorkerModule)
		local payloadSchemaDescriptor = nil
		local payloadCodec = nil
		if type((config.Job :: any).GetPayloadSchemaDescriptor) == "function" then
			payloadSchemaDescriptor = (config.Job :: any):GetPayloadSchemaDescriptor()
		end
		if type((config.Job :: any).GetPayloadCodec) == "function" then
			payloadCodec = (config.Job :: any):GetPayloadCodec()
		end
		self._registeredJobs[jobName] = {
			Job = config.Job,
			WorkerModule = config.WorkerModule,
			DefaultLogicalWorkCount = config.DefaultLogicalWorkCount,
			DefaultBatchSize = config.DefaultBatchSize,
			SharedMemory = nil,
			WorkerPayloadBuffer = nil,
			PayloadSchemaDescriptor = payloadSchemaDescriptor,
			PayloadCodec = payloadCodec,
		}

		return Ok(true)
	end)

	if not ok then
		return _BuildSetupError("ParallelRunnerRegistrationError", tostring(registerOrError), nil)
	end

	return registerOrError
end

function ParallelRunner:HasJob(jobName: string): boolean
	if self._destroyed then
		return false
	end

	return self._registeredJobs[jobName] ~= nil
end

function ParallelRunner:CreateManagedJob(config: TManagedJobConfig): TManagedJob
	assert(not self._destroyed, "ParallelRunner has already been destroyed")
	return ManagedJob.new(self :: any, config)
end

function ParallelRunner:SetSharedMemory(jobName: string, sharedMemory: SharedTable?): TResult<boolean>
	if self._destroyed then
		return _BuildDestroyedError()
	end

	local ok, resultOrError = pcall(function()
		Validation.AssertSetSharedMemory(jobName, sharedMemory)

		local registeredJob = self._registeredJobs[jobName]
		if registeredJob == nil then
			return _BuildSetupError(
				"ParallelRunnerRegistrationError",
				`ParallelRunner:SetSharedMemory("{jobName}") requires a registered job`,
				{
					JobName = jobName,
				}
			)
		end

		self._workplace:SetSharedMemory(jobName, sharedMemory)
		registeredJob.SharedMemory = sharedMemory
		return Ok(true)
	end)

	if not ok then
		return _BuildSetupError("ParallelRunnerSetSharedMemoryError", tostring(resultOrError), {
			JobName = jobName,
		})
	end

	return resultOrError
end

function ParallelRunner:SetWorkerPayload(jobName: string, workerPayload: { [string]: any }?): TResult<boolean>
	if self._destroyed then
		return _BuildDestroyedError()
	end

	local ok, resultOrError = pcall(function()
		Validation.AssertSetWorkerPayload(jobName, workerPayload)

		local registeredJob = self._registeredJobs[jobName]
		if registeredJob == nil then
			return _BuildSetupError(
				"ParallelRunnerRegistrationError",
				`ParallelRunner:SetWorkerPayload("{jobName}") requires a registered job`,
				{
					JobName = jobName,
				}
			)
		end

		if workerPayload ~= nil and registeredJob.PayloadCodec == nil then
			return _BuildSetupError(
				"ParallelRunnerWorkerPayloadSchemaMissing",
				`ParallelRunner:SetWorkerPayload("{jobName}") requires the job to define PayloadSchema`,
				{
					JobName = jobName,
				}
			)
		end

		local workerPayloadBuffer = nil
		if workerPayload ~= nil then
			local encodedBuffer, encodeError = registeredJob.PayloadCodec:Encode(workerPayload)
			if encodedBuffer == nil then
				return _BuildSetupError(
					"ParallelRunnerWorkerPayloadEncodeError",
					`ParallelRunner:SetWorkerPayload("{jobName}") failed to encode WorkerPayload`,
					{
						JobName = jobName,
						Cause = encodeError,
					}
				)
			end
			workerPayloadBuffer = encodedBuffer
		end

		self._workplace:SetWorkerPayload(jobName, workerPayloadBuffer)
		registeredJob.WorkerPayloadBuffer = workerPayloadBuffer
		return Ok(true)
	end)

	if not ok then
		return _BuildSetupError("ParallelRunnerSetWorkerPayloadError", tostring(resultOrError), {
			JobName = jobName,
		})
	end

	return resultOrError
end

function ParallelRunner:Run(request: TRunRequest): TResult<TRunnerRunHandle>
	if self._destroyed then
		return _BuildDestroyedError()
	end

	local ok, runOrError = pcall(function()
		Validation.AssertRunRequest(request :: any)

		-- Resolve the registered job and this run's concrete dispatch settings.
		local registeredJob = self._registeredJobs[request.JobName]
		if registeredJob == nil then
			return _BuildSetupError(
				"ParallelRunnerRunRequestError",
				`ParallelRunner:Run("{request.JobName}") requires a registered job`,
				{
					JobName = request.JobName,
				}
			)
		end

		local logicalWorkCount, logicalWorkCountError = _ResolveLogicalWorkCount(registeredJob, request)
		if logicalWorkCountError ~= nil then
			return logicalWorkCountError
		end

		local resolvedBatchSize = _ResolveBatchSize(self, registeredJob, request)
		local resolvedSharedMemory, sharedMemoryError = _ResolveSharedMemory(registeredJob, request)
		if sharedMemoryError ~= nil then
			return sharedMemoryError
		end
		local resolvedWorkerPayloadBuffer, workerPayloadError = _ResolveWorkerPayloadBuffer(registeredJob, request)
		if workerPayloadError ~= nil then
			return workerPayloadError
		end

		-- Encode args with the compiled transport contract before crossing into the workplace.
		local argsBuffer, encodeError = registeredJob.Job:EncodeArgs(request.Args)
		if argsBuffer == nil then
			return _BuildSetupError(
				"ParallelRunnerArgsEncodeError",
				`ParallelRunner:Run("{request.JobName}") failed to encode args`,
				{
					JobName = request.JobName,
					Cause = encodeError,
				}
			)
		end

		local workplaceRunHandle = self._workplace:Run({
			JobName = request.JobName,
			LogicalWorkCount = logicalWorkCount :: number,
			BatchSize = resolvedBatchSize,
			ArgsBuffer = argsBuffer,
			SharedMemory = resolvedSharedMemory,
			WorkerPayloadBuffer = resolvedWorkerPayloadBuffer,
		})

		local completionPromise = workplaceRunHandle:GetPromise()
			:andThen(function(workplaceRunResult: TWorkplaceRunResult)
				return _MaterializeResult(self:_DecodeRunResult(registeredJob, workplaceRunResult))
			end)
			:catch(function(promiseError)
				return _MaterializeResult(
					_BuildPromiseRejectedResult(request.JobName, workplaceRunHandle:GetRunId(), promiseError)
				)
			end)

		return Ok(RunHandle.new(workplaceRunHandle, completionPromise))
	end)

	if not ok then
		return _BuildSetupError("ParallelRunnerRunSetupError", tostring(runOrError), {
			JobName = request.JobName,
		})
	end

	return runOrError
end

function ParallelRunner:RunAsync(request: TRunRequest): TResult<TRunPromise>
	local runResult = self:Run(request)
	if not runResult.success then
		return runResult
	end

	return Ok(runResult.value:GetPromise())
end

function ParallelRunner:Destroy(): TResult<boolean>
	if self._destroyed then
		return Ok(true)
	end

	local managedJobs = {}
	for job in self._managedJobs do
		table.insert(managedJobs, job)
	end
	for _, job in ipairs(managedJobs) do
		job:Destroy()
	end

	local ok, destroyError = pcall(function()
		self._workplace:Destroy()
	end)
	if not ok then
		return _BuildSetupError("ParallelRunnerDestroyError", tostring(destroyError), nil)
	end

	table.clear(self._registeredJobs)
	table.clear(self._managedJobs)
	self._destroyed = true
	return Ok(true)
end

function ParallelRunner:_DecodeRunResult(registeredJob: TRegisteredJob, workplaceRunResult: TWorkplaceRunResult): TResult<TRunOutput>
	if workplaceRunResult.Status ~= "Completed" then
		return _BuildRunFailureResult(workplaceRunResult)
	end

	-- Decode each shard in order, then concatenate rows into one final output.
	local rows = {}
	for _, shardCompletion in ipairs(workplaceRunResult.ShardCompletions) do
		local decodedRows, _, decodeError = registeredJob.Job:DecodeResultBatch(shardCompletion.ResultBuffer)
		if decodedRows == nil then
			return _BuildDecodeError(
				workplaceRunResult.JobName,
				workplaceRunResult.RunId,
				shardCompletion.ShardIndex,
				decodeError :: string
			)
		end

		if type(decodedRows) ~= "table" then
			return _BuildMalformedShardError(
				workplaceRunResult.JobName,
				workplaceRunResult.RunId,
				shardCompletion.ShardIndex
			)
		end

		for _, row in ipairs(decodedRows) do
			table.insert(rows, row)
		end
	end

	return Ok(table.freeze({
		RunId = workplaceRunResult.RunId,
		JobName = workplaceRunResult.JobName,
		Status = workplaceRunResult.Status,
		LogicalWorkCount = workplaceRunResult.LogicalWorkCount,
		BatchSize = workplaceRunResult.BatchSize,
		ShardCount = workplaceRunResult.ShardCount,
		Rows = table.freeze(rows),
	}))
end

return table.freeze(ParallelRunner)
