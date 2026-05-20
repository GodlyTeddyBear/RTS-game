--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Promise = require(ReplicatedStorage.Packages.Promise)
local InstancePlus = require(ReplicatedStorage.Utilities.InstancePlus)

local Protocol = require(script.Parent.Protocol)
local RunHandle = require(script.Parent.RunHandle)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TActorSlot = Types.TActorSlot
type TRegisteredJob = Types.TRegisteredJob
type TRunError = Types.TRunError
type TRunHandle = Types.TRunHandle
type TRunRecord = Types.TRunRecord
type TRunRequest = Types.TRunRequest
type TRunResult = Types.TRunResult
type TSchemaDescriptor = Types.TSchemaDescriptor
type TShardCompletion = Types.TShardCompletion
type TShardRecord = Types.TShardRecord
type TWorkplace = Types.TWorkplace
type TWorkplaceConfig = Types.TWorkplaceConfig

local WorkerTemplate = script.Parent:WaitForChild("Worker") :: Script

local Workplace = {}
Workplace.__index = Workplace

local Recycler = {
	Initialized = false,
	NextActorId = 0,
	NextWorkplaceId = 0,
	RootFolder = nil :: Folder?,
	AvailableFolder = nil :: Folder?,
	WorkplacesFolder = nil :: Folder?,
	AvailableActors = {} :: { TActorSlot },
	ActorSlotsById = {} :: { [number]: TActorSlot },
}

local function _RemoveArrayValue(list: { any }, value: any)
	local index = table.find(list, value)
	if index ~= nil then
		table.remove(list, index)
	end
end

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

local function _EnsureRecycler()
	if Recycler.Initialized then
		return
	end

	local rootFolder = InstancePlus.new("Folder", {
		Name = "ParallelActorsRuntime",
		Parent = ServerScriptService,
	})
	local availableFolder = InstancePlus.new("Folder", {
		Name = "AvailableActors",
		Parent = rootFolder,
	})
	local workplacesFolder = InstancePlus.new("Folder", {
		Name = "Workplaces",
		Parent = rootFolder,
	})

	Recycler.RootFolder = rootFolder
	Recycler.AvailableFolder = availableFolder
	Recycler.WorkplacesFolder = workplacesFolder
	Recycler.Initialized = true
end

local function _CreateActorSlot(): TActorSlot
	Recycler.NextActorId += 1
	local actorId = Recycler.NextActorId

	local actor = InstancePlus.new("Actor", {
		Name = `ParallelActor_{actorId}`,
		Parent = Recycler.AvailableFolder,
	})
	actor:SetAttribute("ParallelActorsActorId", actorId)

	local actorSlot: TActorSlot = {
		ActorId = actorId,
		Actor = actor,
		WorkerScript = nil,
		State = "Available",
		ReleaseOnIdle = false,
	}

	Recycler.ActorSlotsById[actorId] = actorSlot
	return actorSlot
end

local function _WaitForWorkerReady(workerScript: Script)
	if workerScript:GetAttribute("ParallelActorsReady") == true then
		return
	end

	local readyConnection: RBXScriptConnection?
	local ready = false

	readyConnection = workerScript:GetAttributeChangedSignal("ParallelActorsReady"):Connect(function()
		if workerScript:GetAttribute("ParallelActorsReady") == true then
			ready = true
		end
	end)

	while not ready and workerScript.Parent ~= nil do
		if workerScript:GetAttribute("ParallelActorsReady") == true then
			ready = true
			break
		end
		task.wait()
	end

	if readyConnection ~= nil then
		readyConnection:Disconnect()
	end
end

local function _AttachWorkerScript(actorSlot: TActorSlot)
	if actorSlot.WorkerScript ~= nil then
		actorSlot.WorkerScript:Destroy()
		actorSlot.WorkerScript = nil
	end

	local workerScript = WorkerTemplate:Clone()
	workerScript:SetAttribute("ParallelActorsReady", false)
	workerScript.Parent = actorSlot.Actor
	actorSlot.WorkerScript = workerScript

	_WaitForWorkerReady(workerScript)
end

local function _BuildSchemaDescriptor(schema: any): TSchemaDescriptor
	local descriptor = {}

	for _, field in schema.Numeric do
		descriptor[field.Key] = field.Name
	end

	return table.freeze(descriptor)
end

local function _AcquireActorSlot(): TActorSlot
	local actorSlot = table.remove(Recycler.AvailableActors)
	if actorSlot == nil then
		return _CreateActorSlot()
	end

	return actorSlot
end

function Workplace.new(config: TWorkplaceConfig): TWorkplace
	Validation.AssertWorkplaceConfig(config :: any)
	_EnsureRecycler()

	local self = setmetatable({}, Workplace)

	Recycler.NextWorkplaceId += 1

	self._name = config.Name or "ParallelActorsWorkplace"
	self._actorCount = config.ActorCount
	self._defaultBatchSize = config.DefaultBatchSize
	self._nextRunId = 0
	self._registeredJobs = {} :: { [string]: TRegisteredJob }
	self._sharedMemoryByJobName = {} :: { [string]: SharedTable }
	self._workerPayloadBufferByJobName = {} :: { [string]: buffer }
	self._runsById = {} :: { [number]: TRunRecord }
	self._pendingShards = {} :: { TShardRecord }
	self._idleActors = {} :: { TActorSlot }
	self._busyActors = {} :: { [TActorSlot]: TShardRecord }
	self._hiredActors = {} :: { TActorSlot }
	self._destroyed = false

	self._actorFolder = InstancePlus.new("Folder", {
		Name = `{self._name}_{Recycler.NextWorkplaceId}`,
		Parent = Recycler.WorkplacesFolder,
	})

	for _ = 1, config.ActorCount do
		self:_HireActor()
	end

	return self :: any
end

function Workplace:RegisterJob(jobName: string, executor)
	self:_AssertAlive()
	Validation.AssertJobRegistration(jobName, executor)
	error(`ParallelActors:RegisterJob("{jobName}") is unsupported in the real actor runtime; use RegisterCompiledJob`, 2)
end

function Workplace:RegisterCompiledJob(job, workerModule: ModuleScript)
	self:_AssertAlive()
	Validation.AssertCompiledJobRegistration(job, workerModule)

	local jobName = job:GetName()
	assert(self._registeredJobs[jobName] == nil, `ParallelActors:RegisterCompiledJob("{jobName}") cannot overwrite an existing job`)

	local schemas = job:GetSchemas()
	local registeredJob: TRegisteredJob = {
		Name = jobName,
		Version = job:GetVersion(),
		WorkerModule = workerModule,
		ArgsSchemaDescriptor = _BuildSchemaDescriptor(schemas.Args),
		ResultSchemaDescriptor = _BuildSchemaDescriptor(schemas.Result),
		PayloadSchemaDescriptor = if type(job.GetPayloadSchemaDescriptor) == "function"
			then job:GetPayloadSchemaDescriptor()
			else nil,
	}

	self._registeredJobs[jobName] = registeredJob

	for _, actorSlot in ipairs(self._hiredActors) do
		self:_RegisterJobOnActor(actorSlot, registeredJob)
		local sharedMemory = self._sharedMemoryByJobName[jobName]
		if sharedMemory ~= nil then
			self:_SetActorSharedMemory(actorSlot, jobName, sharedMemory)
		end
		local workerPayloadBuffer = self._workerPayloadBufferByJobName[jobName]
		if workerPayloadBuffer ~= nil then
			self:_SetActorWorkerPayload(actorSlot, jobName, workerPayloadBuffer)
		end
	end
end

function Workplace:HasJob(jobName: string): boolean
	self:_AssertAlive()
	return self._registeredJobs[jobName] ~= nil
end

function Workplace:SetSharedMemory(jobName: string, sharedMemory: SharedTable?)
	self:_AssertAlive()
	Validation.AssertSharedMemory(jobName, sharedMemory)
	assert(self._registeredJobs[jobName] ~= nil, `ParallelActors:SetSharedMemory("{jobName}") requires a registered job`)

	self._sharedMemoryByJobName[jobName] = sharedMemory :: any

	for _, actorSlot in ipairs(self._hiredActors) do
		self:_SetActorSharedMemory(actorSlot, jobName, sharedMemory)
	end
end

function Workplace:SetWorkerPayload(jobName: string, workerPayloadBuffer: buffer?)
	self:_AssertAlive()
	Validation.AssertWorkerPayload(jobName, workerPayloadBuffer)
	assert(self._registeredJobs[jobName] ~= nil, `ParallelActors:SetWorkerPayload("{jobName}") requires a registered job`)

	self._workerPayloadBufferByJobName[jobName] = workerPayloadBuffer :: any

	for _, actorSlot in ipairs(self._hiredActors) do
		self:_SetActorWorkerPayload(actorSlot, jobName, workerPayloadBuffer)
	end
end

function Workplace:Run(request: TRunRequest): TRunHandle
	self:_AssertAlive()
	Validation.AssertRunRequest(request :: any, self._registeredJobs[request.JobName] ~= nil)

	local resolvedBatchSize = self:_ResolveBatchSize(request.LogicalWorkCount, request.BatchSize)
	local shardRecords = self:_BuildShardRecords(request, resolvedBatchSize)

	local runRecord = self:_CreateRunRecord(request, resolvedBatchSize, #shardRecords)
	local runHandle = RunHandle.new(self :: any, runRecord)
	runRecord.Handle = runHandle
	self._runsById[runRecord.RunId] = runRecord
	self:_AttachRunListener(runRecord)

	if #shardRecords == 0 then
		runRecord.Status = "Completed"
		self:_ResolveRun(runRecord)
		self:_MaybeCleanupRunArtifacts(runRecord)
		return runHandle
	end

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

	local runIds = {}
	for runId in self._runsById do
		table.insert(runIds, runId)
	end

	for _, runId in ipairs(runIds) do
		self:_CancelRun(runId)
	end

	table.clear(self._pendingShards)
	table.clear(self._registeredJobs)
	table.clear(self._sharedMemoryByJobName)
	table.clear(self._workerPayloadBufferByJobName)

	for _, actorSlot in ipairs(self._idleActors) do
		self:_ReturnActorToRecycler(actorSlot)
	end
	table.clear(self._idleActors)

	for actorSlot in self._busyActors do
		actorSlot.ReleaseOnIdle = true
	end

	self._destroyed = true
	self:_FinalizeDestroyIfIdle()
end

function Workplace:_AssertAlive()
	assert(not self._destroyed, "ParallelActors workplace has already been destroyed")
end

function Workplace:_HireActor()
	local actorSlot = _AcquireActorSlot()
	actorSlot.State = "HiredIdle"
	actorSlot.ReleaseOnIdle = false
	actorSlot.Actor.Parent = self._actorFolder
	_AttachWorkerScript(actorSlot)

	table.insert(self._hiredActors, actorSlot)
	table.insert(self._idleActors, actorSlot)

	for _, registeredJob in self._registeredJobs do
		self:_RegisterJobOnActor(actorSlot, registeredJob)
	end

	for jobName, sharedMemory in self._sharedMemoryByJobName do
		if self._registeredJobs[jobName] ~= nil then
			self:_SetActorSharedMemory(actorSlot, jobName, sharedMemory)
		end
	end

	for jobName, workerPayloadBuffer in self._workerPayloadBufferByJobName do
		if self._registeredJobs[jobName] ~= nil then
			self:_SetActorWorkerPayload(actorSlot, jobName, workerPayloadBuffer)
		end
	end
end

function Workplace:_RegisterJobOnActor(actorSlot: TActorSlot, registeredJob: TRegisteredJob)
	actorSlot.Actor:SendMessage(
		Protocol.RegisterJob,
		registeredJob.Name,
		registeredJob.Version,
		registeredJob.ArgsSchemaDescriptor,
		registeredJob.ResultSchemaDescriptor,
		registeredJob.PayloadSchemaDescriptor,
		registeredJob.WorkerModule
	)
end

function Workplace:_SetActorSharedMemory(actorSlot: TActorSlot, jobName: string, sharedMemory: SharedTable?)
	actorSlot.Actor:SendMessage(Protocol.SetSharedMemory, jobName, sharedMemory)
end

function Workplace:_SetActorWorkerPayload(actorSlot: TActorSlot, jobName: string, workerPayloadBuffer: buffer?)
	actorSlot.Actor:SendMessage(Protocol.SetWorkerPayload, jobName, workerPayloadBuffer)
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
			WorkerPayloadBuffer = request.WorkerPayloadBuffer,
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
		ResultBindable = Instance.new("BindableEvent"),
		ResultConnection = nil,
	}
end

function Workplace:_AttachRunListener(runRecord: TRunRecord)
	local bindable = runRecord.ResultBindable
	if bindable == nil then
		return
	end

	runRecord.ResultConnection = bindable.Event:Connect(function(
		actorId: number,
		runId: number,
		jobName: string,
		shardIndex: number,
		startTaskId: number,
		batchSize: number,
		resultBuffer: buffer?,
		errorMessage: string?
	)
		local actorSlot = Recycler.ActorSlotsById[actorId]
		if actorSlot == nil then
			return
		end

		local shardRecord = self._busyActors[actorSlot]
		if shardRecord == nil then
			return
		end

		if shardRecord.RunId ~= runId or shardRecord.ShardIndex ~= shardIndex then
			return
		end

		if errorMessage ~= nil then
			self:_FailRun(shardRecord, {
				JobName = jobName,
				ShardIndex = shardIndex,
				StartTaskId = startTaskId,
				Message = errorMessage,
				Traceback = nil,
			})
			self:_ReleaseActor(actorSlot, shardRecord)
			return
		end

		if resultBuffer == nil or typeof(resultBuffer) ~= "buffer" then
			self:_FailRun(shardRecord, {
				JobName = jobName,
				ShardIndex = shardIndex,
				StartTaskId = startTaskId,
				Message = "ParallelActors shard executor must resolve with a buffer",
				Traceback = nil,
			})
			self:_ReleaseActor(actorSlot, shardRecord)
			return
		end

		self:_CompleteShard(shardRecord, {
			RunId = runId,
			JobName = jobName,
			ShardIndex = shardIndex,
			StartTaskId = startTaskId,
			BatchSize = batchSize,
			ResultBuffer = resultBuffer,
		})
		self:_ReleaseActor(actorSlot, shardRecord)
	end)
end

function Workplace:_DrainQueue()
	if self._destroyed then
		return
	end

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

		actorSlot.State = "Busy"
		self._busyActors[actorSlot] = shardRecord
		runRecord.QueuedShardCount -= 1
		runRecord.ActiveShardCount += 1
		if runRecord.Status == "Queued" then
			runRecord.Status = "Running"
		end

		self:_DispatchShard(actorSlot, shardRecord, runRecord)
	end
end

function Workplace:_DispatchShard(actorSlot: TActorSlot, shardRecord: TShardRecord, runRecord: TRunRecord)
	local bindable = runRecord.ResultBindable
	if bindable == nil then
		self:_FailRun(shardRecord, {
			JobName = shardRecord.JobName,
			ShardIndex = shardRecord.ShardIndex,
			StartTaskId = shardRecord.StartTaskId,
			Message = "ParallelActors run is missing a result bindable",
			Traceback = nil,
		})
		self:_ReleaseActor(actorSlot, shardRecord)
		return
	end

	actorSlot.Actor:SendMessage(
		Protocol.RunShard,
		shardRecord.RunId,
		shardRecord.JobName,
		shardRecord.ShardIndex,
		shardRecord.StartTaskId,
		shardRecord.BatchSize,
		shardRecord.LogicalWorkCount,
		shardRecord.ArgsBuffer,
		bindable,
		shardRecord.SharedMemory,
		shardRecord.WorkerPayloadBuffer
	)
end

function Workplace:_CompleteShard(shardRecord: TShardRecord, shardCompletion: TShardCompletion)
	local runRecord = self._runsById[shardRecord.RunId]
	if runRecord == nil then
		return
	end

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
	self:_MaybeCleanupRunArtifacts(runRecord)
end

function Workplace:_CancelRun(runId: number): boolean
	local runRecord = self._runsById[runId]
	if runRecord == nil or self:_IsTerminal(runRecord.Status) then
		return false
	end

	runRecord.Status = "Cancelled"
	self:_RemoveQueuedShardsForRun(runRecord)
	self:_ResolveRun(runRecord)
	self:_MaybeCleanupRunArtifacts(runRecord)
	return true
end

function Workplace:_RemoveQueuedShardsForRun(runRecord: TRunRecord)
	local keptShards = table.create(#self._pendingShards)

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

	if actorSlot.ReleaseOnIdle or self._destroyed then
		self:_ReturnActorToRecycler(actorSlot)
	else
		actorSlot.State = "HiredIdle"
		table.insert(self._idleActors, actorSlot)
		self:_DrainQueue()
	end

	if runRecord ~= nil then
		self:_MaybeCleanupRunArtifacts(runRecord)
	end

	self:_FinalizeDestroyIfIdle()
end

function Workplace:_ReturnActorToRecycler(actorSlot: TActorSlot)
	_RemoveArrayValue(self._idleActors, actorSlot)
	_RemoveArrayValue(self._hiredActors, actorSlot)
	self._busyActors[actorSlot] = nil

	if actorSlot.WorkerScript ~= nil then
		actorSlot.WorkerScript:Destroy()
		actorSlot.WorkerScript = nil
	end

	actorSlot.State = "Available"
	actorSlot.ReleaseOnIdle = false
	actorSlot.Actor.Parent = Recycler.AvailableFolder
	table.insert(Recycler.AvailableActors, actorSlot)
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

function Workplace:_MaybeCleanupRunArtifacts(runRecord: TRunRecord)
	if not runRecord.Settled or runRecord.ActiveShardCount > 0 then
		return
	end

	if runRecord.ResultConnection ~= nil then
		runRecord.ResultConnection:Disconnect()
		runRecord.ResultConnection = nil
	end

	if runRecord.ResultBindable ~= nil then
		runRecord.ResultBindable:Destroy()
		runRecord.ResultBindable = nil
	end

	self._runsById[runRecord.RunId] = nil
end

function Workplace:_FinalizeDestroyIfIdle()
	if not self._destroyed then
		return
	end

	if next(self._busyActors) ~= nil then
		return
	end

	if self._actorFolder ~= nil then
		self._actorFolder:Destroy()
		self._actorFolder = nil
	end
end

function Workplace:_IsTerminal(status: string): boolean
	return status == "Completed" or status == "Failed" or status == "Cancelled"
end

return table.freeze(Workplace)
