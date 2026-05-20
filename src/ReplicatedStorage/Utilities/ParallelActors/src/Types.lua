--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

export type TRunStatus = "Queued" | "Running" | "Completed" | "Failed" | "Cancelled"

export type TRunRequest = {
	JobName: string,
	LogicalWorkCount: number,
	BatchSize: number?,
	ArgsBuffer: buffer,
	SharedMemory: SharedTable?,
}

export type TShardRequest = {
	RunId: number,
	JobName: string,
	ShardIndex: number,
	StartTaskId: number,
	BatchSize: number,
	LogicalWorkCount: number,
	ArgsBuffer: buffer,
	SharedMemory: SharedTable?,
}

export type TRunError = {
	JobName: string,
	ShardIndex: number,
	StartTaskId: number,
	Message: string,
	Traceback: string?,
}

export type TShardCompletion = {
	RunId: number,
	JobName: string,
	ShardIndex: number,
	StartTaskId: number,
	BatchSize: number,
	ResultBuffer: buffer,
}

export type TRunSnapshot = {
	RunId: number,
	JobName: string,
	Status: TRunStatus,
	LogicalWorkCount: number,
	BatchSize: number,
	ShardCount: number,
	QueuedShardCount: number,
	ActiveShardCount: number,
	CompletedShardCount: number,
	FirstError: TRunError?,
}

export type TRunResult = {
	RunId: number,
	JobName: string,
	Status: TRunStatus,
	LogicalWorkCount: number,
	BatchSize: number,
	ShardCount: number,
	ShardCompletions: { TShardCompletion },
	FirstError: TRunError?,
}

export type TRunHandle = {
	GetRunId: (self: TRunHandle) -> number,
	GetJobName: (self: TRunHandle) -> string,
	GetStatus: (self: TRunHandle) -> TRunStatus,
	IsQueued: (self: TRunHandle) -> boolean,
	IsRunning: (self: TRunHandle) -> boolean,
	IsCompleted: (self: TRunHandle) -> boolean,
	IsFailed: (self: TRunHandle) -> boolean,
	IsCancelled: (self: TRunHandle) -> boolean,
	IsDone: (self: TRunHandle) -> boolean,
	GetPromise: (self: TRunHandle) -> typeof(Promise.new(function() end)),
	Await: (self: TRunHandle) -> TRunResult,
	Cancel: (self: TRunHandle) -> boolean,
	GetSnapshot: (self: TRunHandle) -> TRunSnapshot,
	GetLogicalWorkCount: (self: TRunHandle) -> number,
	GetBatchSize: (self: TRunHandle) -> number,
	GetShardCount: (self: TRunHandle) -> number,
	GetQueuedShardCount: (self: TRunHandle) -> number,
	GetActiveShardCount: (self: TRunHandle) -> number,
	GetCompletedShardCount: (self: TRunHandle) -> number,
}

export type TJobExecutor = (request: TShardRequest) -> (buffer | typeof(Promise.new(function() end)))

export type TWorkplaceConfig = {
	Name: string?,
	ActorCount: number,
	DefaultBatchSize: number?,
}

export type TSchemaDescriptor = {
	[string]: string,
}

export type TRegisteredJob = {
	Name: string,
	Version: number,
	WorkerModule: ModuleScript,
	ArgsSchemaDescriptor: TSchemaDescriptor,
	ResultSchemaDescriptor: TSchemaDescriptor,
}

export type TActorSlot = {
	ActorId: number,
	Actor: Actor,
	WorkerScript: Script?,
	State: "Available" | "HiredIdle" | "Busy",
	ReleaseOnIdle: boolean?,
}

export type TShardRecord = TShardRequest & {
	SharedMemory: SharedTable?,
}

export type TRunRecord = {
	RunId: number,
	JobName: string,
	Status: TRunStatus,
	LogicalWorkCount: number,
	BatchSize: number,
	ShardCount: number,
	QueuedShardCount: number,
	ActiveShardCount: number,
	CompletedShardCount: number,
	ShardCompletionsByIndex: { [number]: TShardCompletion },
	FirstError: TRunError?,
	Handle: TRunHandle,
	Promise: typeof(Promise.new(function() end)),
	Resolve: (result: TRunResult) -> (),
	Reject: (err: any) -> (),
	Settled: boolean,
	ResultBindable: BindableEvent?,
	ResultConnection: RBXScriptConnection?,
}

export type TWorkplace = {
	RegisterJob: (self: TWorkplace, jobName: string, executor: TJobExecutor) -> (),
	RegisterCompiledJob: (self: TWorkplace, job: any, workerModule: ModuleScript) -> (),
	HasJob: (self: TWorkplace, jobName: string) -> boolean,
	SetSharedMemory: (self: TWorkplace, jobName: string, sharedMemory: SharedTable?) -> (),
	Run: (self: TWorkplace, request: TRunRequest) -> TRunHandle,
	Destroy: (self: TWorkplace) -> (),
}

local Types = {}

return Types
