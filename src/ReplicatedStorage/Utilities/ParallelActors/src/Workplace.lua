--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local RunHandle = require(script.Parent.RunHandle)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TActorSlot = Types.TActorSlot
type TJobExecutor = Types.TJobExecutor
type TRegisteredJob = Types.TRegisteredJob
type TRunError = Types.TRunError
type TRunHandle = Types.TRunHandle
type TRunRecord = Types.TRunRecord
type TRunRequest = Types.TRunRequest
type TRunResult = Types.TRunResult
type TShardCompletion = Types.TShardCompletion
type TShardRecord = Types.TShardRecord
type TWorkplace = Types.TWorkplace
type TWorkplaceConfig = Types.TWorkplaceConfig

local Workplace = {}
Workplace.__index = Workplace

local function _CloneError(runError: TRunError?): TRunError?
	if runError == nil then
		return nil
	end

	return table.freeze({
		JobName = runError.JobName,
		ShardIndex = runError.ShardIndex,
		StartTaskId = runError.StartTaskId,
		Message = runError.Message,
		Traceback = runError.Traceback,
	})
end

local function _CloneShardCompletion(shardCompletion: TShardCompletion): TShardCompletion
	return table.freeze({
		RunId = shardCompletion.RunId,
		JobName = shardCompletion.JobName,
		ShardIndex = shardCompletion.ShardIndex,
		StartTaskId = shardCompletion.StartTaskId,
		BatchSize = shardCompletion.BatchSize,
		ResultBuffer = buffer.fromstring(buffer.tostring(shardCompletion.ResultBuffer)),
	})
end

function Workplace.new(config: TWorkplaceConfig): TWorkplace
	Validation.AssertWorkplaceConfig(config :: any)

	local self = setmetatable({}, Workplace)

	-- Variables
	self._name = config.Name or "ParallelActorsWorkplace"
	self._actorCount = config.ActorCount
	self._defaultBatchSize = config.DefaultBatchSize
	self._nextRunId = 0
	self._registeredJobs = {} :: { [string]: TRegisteredJob }
	self._runsById = {} :: { [number]: TRunRecord }
	self._pendingShards = {} :: { TShardRecord }
	self._idleActors = table.create(config.ActorCount) :: { TActorSlot }
	self._busyActors = {} :: { [TActorSlot]: TShardRecord }
	self._destroyed = false

	-- Build the workplace's worker slots.
	for actorId = 1, config.ActorCount do
		self._idleActors[actorId] = {
			ActorId = actorId,
			State = "HiredIdle",
		}
	end

	return self :: any
end

function Workplace:RegisterJob(jobName: string, executor: TJobExecutor)
	self:_AssertAlive()
	Validation.AssertJobRegistration(jobName, executor)
	assert(self._registeredJobs[jobName] == nil, `ParallelActors:RegisterJob("{jobName}") cannot overwrite an existing job`)

	self._registeredJobs[jobName] = {
		Name = jobName,
		Execute = executor,
	}
end

function Workplace:HasJob(jobName: string): boolean
	self:_AssertAlive()
	return self._registeredJobs[jobName] ~= nil
end

function Workplace:Run(request: TRunRequest): TRunHandle
	self:_AssertAlive()
	Validation.AssertRunRequest(request :: any, self._registeredJobs[request.JobName] ~= nil)

	-- Resolve this run's batching before building shard records.
	local resolvedBatchSize = self:_ResolveBatchSize(request.LogicalWorkCount, request.BatchSize)
	local shardRecords = self:_BuildShardRecords(request, resolvedBatchSize)

	-- Create the tracked run record and its handle.
	local runRecord = self:_CreateRunRecord(request, resolvedBatchSize, #shardRecords)
	local runHandle = RunHandle.new(self :: any, runRecord)
	runRecord.Handle = runHandle
	self._runsById[runRecord.RunId] = runRecord

	-- Zero-work runs settle immediately as completed.
	if #shardRecords == 0 then
		runRecord.Status = "Completed"
		self:_ResolveRun(runRecord)
		return runHandle
	end

	-- Queue the run's shards in FIFO order, then start draining into idle actors.
	for _, shardRecord in ipairs(shardRecords) do
		table.insert(self._pendingShards, shardRecord)
	end

	self:_DrainQueue()
	return runHandle
end

function Workplace:Destroy()
	if self._destroyed then
		return
	end

	-- Cancel every tracked run before tearing down queues and slots.
	local runIds = {}
	for runId in self._runsById do
		table.insert(runIds, runId)
	end

	for _, runId in ipairs(runIds) do
		self:_CancelRun(runId)
	end

	table.clear(self._pendingShards)
	table.clear(self._busyActors)
	table.clear(self._idleActors)
	table.clear(self._registeredJobs)
	self._destroyed = true
end

function Workplace:_AssertAlive()
	assert(not self._destroyed, "ParallelActors workplace has already been destroyed")
end

function Workplace:_ResolveBatchSize(logicalWorkCount: number, requestedBatchSize: number?): number
	if requestedBatchSize ~= nil then
		return requestedBatchSize
	end

	if self._defaultBatchSize ~= nil then
		return self._defaultBatchSize
	end

	if logicalWorkCount == 0 then
		return 1
	end

	return math.max(1, math.ceil(logicalWorkCount / self._actorCount))
end

function Workplace:_BuildShardRecords(request: TRunRequest, batchSize: number): { TShardRecord }
	local shardRecords = {}
	local shardIndex = 0

	for startTaskId = 1, request.LogicalWorkCount, batchSize do
		shardIndex += 1
		table.insert(shardRecords, {
			RunId = self._nextRunId + 1,
			JobName = request.JobName,
			ShardIndex = shardIndex,
			StartTaskId = startTaskId,
			BatchSize = batchSize,
			LogicalWorkCount = request.LogicalWorkCount,
			ArgsBuffer = request.ArgsBuffer,
			SharedMemory = request.SharedMemory,
		})
	end

	return shardRecords
end

function Workplace:_CreateRunRecord(request: TRunRequest, batchSize: number, shardCount: number): TRunRecord
	self._nextRunId += 1

	local resolveRun
	local rejectRun
	local promise = Promise.new(function(resolve, reject)
		resolveRun = resolve
		rejectRun = reject
	end)

	return {
		RunId = self._nextRunId,
		JobName = request.JobName,
		Status = "Queued",
		LogicalWorkCount = request.LogicalWorkCount,
		BatchSize = batchSize,
		ShardCount = shardCount,
		QueuedShardCount = shardCount,
		ActiveShardCount = 0,
		CompletedShardCount = 0,
		ShardCompletionsByIndex = {},
		FirstError = nil,
		Handle = nil :: any,
		Promise = promise,
		Resolve = resolveRun,
		Reject = rejectRun,
		Settled = false,
	}
end

function Workplace:_DrainQueue()
	while #self._idleActors > 0 and #self._pendingShards > 0 do
		local shardRecord = table.remove(self._pendingShards, 1)
		if shardRecord == nil then
			return
		end

		local runRecord = self._runsById[shardRecord.RunId]
		if runRecord == nil or self:_IsTerminal(runRecord.Status) then
			continue
		end

		local actorSlot = table.remove(self._idleActors)
		if actorSlot == nil then
			table.insert(self._pendingShards, 1, shardRecord)
			return
		end

		-- Transition the actor and run into active work before handing off execution.
		actorSlot.State = "Busy"
		self._busyActors[actorSlot] = shardRecord
		runRecord.QueuedShardCount -= 1
		runRecord.ActiveShardCount += 1
		if runRecord.Status == "Queued" then
			runRecord.Status = "Running"
		end

		self:_DispatchShard(actorSlot, shardRecord)
	end
end

function Workplace:_DispatchShard(actorSlot: TActorSlot, shardRecord: TShardRecord)
	local registeredJob = self._registeredJobs[shardRecord.JobName]
	local runRecord = self._runsById[shardRecord.RunId]
	if registeredJob == nil or runRecord == nil then
		self:_FailRun(shardRecord, {
			JobName = shardRecord.JobName,
			ShardIndex = shardRecord.ShardIndex,
			StartTaskId = shardRecord.StartTaskId,
			Message = `ParallelActors missing registered job "{shardRecord.JobName}" during dispatch`,
			Traceback = nil,
		})
		self:_ReleaseActor(actorSlot, shardRecord)
		return
	end

	-- Execute this shard asynchronously so idle actors can continue draining queued work.
	task.spawn(function()
		local ok, executionResult = pcall(registeredJob.Execute, {
			RunId = shardRecord.RunId,
			JobName = shardRecord.JobName,
			ShardIndex = shardRecord.ShardIndex,
			StartTaskId = shardRecord.StartTaskId,
			BatchSize = shardRecord.BatchSize,
			LogicalWorkCount = shardRecord.LogicalWorkCount,
			ArgsBuffer = shardRecord.ArgsBuffer,
			SharedMemory = shardRecord.SharedMemory,
		})

		if not ok then
			self:_FailRun(shardRecord, {
				JobName = shardRecord.JobName,
				ShardIndex = shardRecord.ShardIndex,
				StartTaskId = shardRecord.StartTaskId,
				Message = tostring(executionResult),
				Traceback = debug.traceback(tostring(executionResult), 2),
			})
			self:_ReleaseActor(actorSlot, shardRecord)
			return
		end

		self:_ObserveShardResult(actorSlot, shardRecord, executionResult)
	end)
end

function Workplace:_ObserveShardResult(actorSlot: TActorSlot, shardRecord: TShardRecord, executionResult: any)
	local completionPromise = self:_WrapExecutionResult(executionResult)

	completionPromise:andThen(function(resultBuffer)
		if typeof(resultBuffer) ~= "buffer" then
			self:_FailRun(shardRecord, {
				JobName = shardRecord.JobName,
				ShardIndex = shardRecord.ShardIndex,
				StartTaskId = shardRecord.StartTaskId,
				Message = "ParallelActors shard executor must resolve with a buffer",
				Traceback = nil,
			})
			return
		end

		self:_CompleteShard(shardRecord, {
			RunId = shardRecord.RunId,
			JobName = shardRecord.JobName,
			ShardIndex = shardRecord.ShardIndex,
			StartTaskId = shardRecord.StartTaskId,
			BatchSize = shardRecord.BatchSize,
			ResultBuffer = resultBuffer,
		})
		self:_ReleaseActor(actorSlot, shardRecord)
	end):catch(function(runError)
		self:_FailRun(shardRecord, {
			JobName = shardRecord.JobName,
			ShardIndex = shardRecord.ShardIndex,
			StartTaskId = shardRecord.StartTaskId,
			Message = tostring(runError),
			Traceback = debug.traceback(tostring(runError), 2),
		})
		self:_ReleaseActor(actorSlot, shardRecord)
	end)
end

function Workplace:_WrapExecutionResult(executionResult: any)
	if type(executionResult) == "table" and type(executionResult.andThen) == "function" then
		return executionResult
	end

	return Promise.resolve(executionResult)
end

function Workplace:_CompleteShard(shardRecord: TShardRecord, shardCompletion: TShardCompletion)
	local runRecord = self._runsById[shardRecord.RunId]
	if runRecord == nil then
		return
	end

	-- Ignore late completions after the run has already settled as failed/cancelled.
	if self:_IsTerminal(runRecord.Status) and runRecord.Status ~= "Completed" then
		return
	end

	runRecord.CompletedShardCount += 1
	runRecord.ShardCompletionsByIndex[shardCompletion.ShardIndex] = shardCompletion

	if runRecord.CompletedShardCount == runRecord.ShardCount then
		runRecord.Status = "Completed"
		self:_ResolveRun(runRecord)
	end
end

function Workplace:_FailRun(shardRecord: TShardRecord, runError: TRunError)
	local runRecord = self._runsById[shardRecord.RunId]
	if runRecord == nil or self:_IsTerminal(runRecord.Status) then
		return
	end

	runRecord.Status = "Failed"
	runRecord.FirstError = runError
	self:_RemoveQueuedShardsForRun(runRecord)
	self:_ResolveRun(runRecord)
end

function Workplace:_CancelRun(runId: number): boolean
	local runRecord = self._runsById[runId]
	if runRecord == nil or self:_IsTerminal(runRecord.Status) then
		return false
	end

	runRecord.Status = "Cancelled"
	self:_RemoveQueuedShardsForRun(runRecord)
	self:_ResolveRun(runRecord)
	return true
end

function Workplace:_RemoveQueuedShardsForRun(runRecord: TRunRecord)
	local keptShards = table.create(#self._pendingShards)

	-- Remove this run's queued shards immediately while preserving FIFO order for the rest.
	for _, pendingShard in ipairs(self._pendingShards) do
		if pendingShard.RunId == runRecord.RunId then
			continue
		end

		table.insert(keptShards, pendingShard)
	end

	runRecord.QueuedShardCount = 0
	self._pendingShards = keptShards
end

function Workplace:_ReleaseActor(actorSlot: TActorSlot, shardRecord: TShardRecord)
	local activeShard = self._busyActors[actorSlot]
	if activeShard == nil then
		return
	end

	local runRecord = self._runsById[shardRecord.RunId]
	if runRecord ~= nil and runRecord.ActiveShardCount > 0 then
		runRecord.ActiveShardCount -= 1
	end

	self._busyActors[actorSlot] = nil
	actorSlot.State = "HiredIdle"
	table.insert(self._idleActors, actorSlot)
	self:_DrainQueue()
end

function Workplace:_ResolveRun(runRecord: TRunRecord)
	if runRecord.Settled then
		return
	end

	runRecord.Settled = true
	runRecord.Resolve(self:_BuildRunResult(runRecord))
end

function Workplace:_BuildRunResult(runRecord: TRunRecord): TRunResult
	local shardCompletions = {}

	for shardIndex = 1, runRecord.ShardCount do
		local shardCompletion = runRecord.ShardCompletionsByIndex[shardIndex]
		if shardCompletion ~= nil then
			table.insert(shardCompletions, _CloneShardCompletion(shardCompletion))
		end
	end

	return table.freeze({
		RunId = runRecord.RunId,
		JobName = runRecord.JobName,
		Status = runRecord.Status,
		LogicalWorkCount = runRecord.LogicalWorkCount,
		BatchSize = runRecord.BatchSize,
		ShardCount = runRecord.ShardCount,
		ShardCompletions = table.freeze(shardCompletions),
		FirstError = _CloneError(runRecord.FirstError),
	})
end

function Workplace:_IsTerminal(status: string): boolean
	return status == "Completed" or status == "Failed" or status == "Cancelled"
end

return table.freeze(Workplace)
