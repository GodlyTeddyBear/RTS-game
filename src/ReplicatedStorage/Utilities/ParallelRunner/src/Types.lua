--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local ParallelActors = require(ReplicatedStorage.Utilities.ParallelActors)
local ParallelLogistics = require(ReplicatedStorage.Utilities.ParallelLogistics)
local Result = require(ReplicatedStorage.Utilities.Result)

export type TResult<T> = Result.Result<T>
export type TRunPromise = typeof(Promise.new(function() end))
type TSignalConnection = {
	Disconnect: (self: TSignalConnection) -> (),
}
export type TCompiledJob = ParallelLogistics.TCompiledJob
export type TWorkplace = ParallelActors.TWorkplace
export type TWorkplaceRunHandle = ParallelActors.TRunHandle
export type TRunStatus = ParallelActors.TRunStatus
export type TWorkplaceRunSnapshot = ParallelActors.TRunSnapshot
export type TWorkplaceRunResult = ParallelActors.TRunResult

export type TRunnerConfig = {
	Name: string?,
	ActorCount: number,
	DefaultBatchSize: number?,
}

export type TMarkerScope = "Arg" | "Result"

export type TAutoFieldMarker = {
	__ParallelRunnerMarker: true,
	MarkerScope: TMarkerScope,
	TypeName: string,
}

export type TAutoSchemaRecord = {
	[string]: any,
}

export type TDefineJobConfig = {
	Name: string,
	Version: number,
	Args: TAutoSchemaRecord,
	Results: TAutoSchemaRecord,
	SharedSchema: { [string]: any }?,
}

export type TWorkerRequest = {
	JobName: string,
	RunId: number,
	ShardIndex: number,
	StartTaskId: number,
	BatchSize: number,
	LogicalWorkCount: number,
	Args: { [string]: any },
	SharedMemory: SharedTable?,
}

export type TWorkerExport = {
	Execute: (request: TWorkerRequest) -> ({ { [string]: any } } | TRunPromise),
}

export type TRegisterJobConfig = {
	Job: TCompiledJob,
	WorkerModule: ModuleScript,
	DefaultLogicalWorkCount: number?,
	DefaultBatchSize: number?,
}

export type TRunRequest = {
	JobName: string,
	Args: { [string]: any },
	LogicalWorkCount: number?,
	BatchSize: number?,
	SharedMemory: SharedTable?,
}

export type TRunOutput = {
	RunId: number,
	JobName: string,
	Status: TRunStatus,
	LogicalWorkCount: number,
	BatchSize: number,
	ShardCount: number,
	Rows: { { [string]: any } },
}

export type TCompletedSignal = {
	Connect: (self: TCompletedSignal, callback: (TResult<TRunOutput>) -> ()) -> TSignalConnection,
	Once: (self: TCompletedSignal, callback: (TResult<TRunOutput>) -> ()) -> TSignalConnection,
	Wait: (self: TCompletedSignal) -> TResult<TRunOutput>,
	DisconnectAll: (self: TCompletedSignal) -> (),
}

export type TRegisteredJob = {
	Job: TCompiledJob,
	WorkerModule: ModuleScript,
	DefaultLogicalWorkCount: number?,
	DefaultBatchSize: number?,
	SharedMemory: SharedTable?,
}

export type TRunnerRunHandle = {
	Completed: TCompletedSignal,
	GetRunId: (self: TRunnerRunHandle) -> number,
	GetJobName: (self: TRunnerRunHandle) -> string,
	GetStatus: (self: TRunnerRunHandle) -> TRunStatus,
	IsQueued: (self: TRunnerRunHandle) -> boolean,
	IsRunning: (self: TRunnerRunHandle) -> boolean,
	IsCompleted: (self: TRunnerRunHandle) -> boolean,
	IsFailed: (self: TRunnerRunHandle) -> boolean,
	IsCancelled: (self: TRunnerRunHandle) -> boolean,
	IsDone: (self: TRunnerRunHandle) -> boolean,
	GetSnapshot: (self: TRunnerRunHandle) -> TWorkplaceRunSnapshot,
	GetPromise: (self: TRunnerRunHandle) -> TRunPromise,
	Await: (self: TRunnerRunHandle) -> TResult<TRunOutput>,
	Cancel: (self: TRunnerRunHandle) -> boolean,
}

export type TRunner = {
	RegisterJob: (self: TRunner, config: TRegisterJobConfig) -> TResult<boolean>,
	HasJob: (self: TRunner, jobName: string) -> boolean,
	SetSharedMemory: (self: TRunner, jobName: string, sharedMemory: SharedTable?) -> TResult<boolean>,
	Run: (self: TRunner, request: TRunRequest) -> TResult<TRunnerRunHandle>,
	RunAsync: (self: TRunner, request: TRunRequest) -> TResult<TRunPromise>,
	Destroy: (self: TRunner) -> TResult<boolean>,
}

local Types = {}

return Types
