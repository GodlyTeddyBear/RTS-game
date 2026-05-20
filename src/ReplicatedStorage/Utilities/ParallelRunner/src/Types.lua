--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local ParallelActors = require(ReplicatedStorage.Utilities.ParallelActors)
local ParallelLogistics = require(ReplicatedStorage.Utilities.ParallelLogistics)
local Result = require(ReplicatedStorage.Utilities.Result)
local SharedPlus = require(ReplicatedStorage.Utilities.SharedPlus)

export type TResult<T> = Result.Result<T>
export type TRunPromise = typeof(Promise.new(function() end))
type TSignalConnection = {
	Disconnect: (self: TSignalConnection) -> (),
}
export type TFieldType =
	"u8" | "u16" | "u32"
	| "i8" | "i16" | "i32"
	| "f32" | "f64"
	| "boolean"
	| "string"
	| "vector2" | "vector2i16"
	| "vector3" | "vector3i16"
	| "cframe" | "cframef32" | "cframe18"
	| "color3" | "color3b16"
export type TResultField = {
	Name: string,
	Type: TFieldType,
	Length: number?,
}
export type TCompiledJob = ParallelLogistics.TCompiledJob
export type TSharedPacket = SharedPlus.TPacket
export type TSharedCompiledHandle = SharedPlus.TCompiledHandle
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

export type TManagedAsyncResult = {
	RequestId: number,
	SessionToken: any?,
	Payload: any?,
	Rows: { { [string]: any } }?,
	Err: TResult<TRunOutput>?,
	CompletedClock: number?,
}

export type TManagedAsyncState = {
	PendingRequestId: number,
	LatestAppliedRequestId: number,
	LatestCompletedResult: TManagedAsyncResult?,
	InFlight: boolean,
	InFlightRequestId: number?,
	InFlightSessionToken: any?,
	LastDispatchClock: number,
}

export type TManagedDispatchStatus = "Dispatched" | "InFlight"
export type TManagedCompletionStatus = "Accepted" | "StaleRequest" | "ReplacedPrevious"
export type TManagedConsumeStatus = "Accepted" | "NoResult" | "StaleRequest" | "SessionMismatch"
export type TManagedJobPolicyPreset = "StrictFreshOnly"
export type TManagedJobPolicyConfig = {
	Preset: TManagedJobPolicyPreset,
}

export type TManagedJobBuildRunRequest = {
	Args: { [string]: any },
	LogicalWorkCount: number,
	BatchSize: number?,
}

export type TManagedJobDispatchStatus = TManagedDispatchStatus
export type TManagedJobConfig = {
	JobName: string,
	BuildSharedMemory: (payload: any) -> TSharedPacket,
	BuildBaseSharedMemory: ((payload: any) -> TSharedPacket?)?,
	BuildRunRequest: (payload: any) -> TManagedJobBuildRunRequest,
	GetSessionToken: ((payload: any) -> any?)?,
	MaxInFlightSeconds: number?,
	Policy: (TManagedJobPolicyPreset | TManagedJobPolicyConfig)?,
}

export type TManagedJobResult = TManagedAsyncResult & {
	PolicyStatus: "Fresh",
}

export type TManagedJobStatus = {
	InFlight: boolean,
	LastDispatchClock: number,
	HasCompletedResult: boolean,
	PolicyPreset: TManagedJobPolicyPreset,
	LastError: TResult<TRunOutput>?,
}

export type TRowFieldValidationResult = {
	IsValid: boolean,
	FieldName: string?,
	Reason: string?,
}

export type TSchemaRowValidationMode = "RequiredOnly" | "Full"
export type TSchemaRowValidationResult = TRowFieldValidationResult & {
	RowIndex: number?,
}

export type TSchemaRowsValidationResult = {
	IsValid: boolean,
	InvalidRowCount: number,
	FirstInvalidRowIndex: number?,
	FirstInvalidFieldName: string?,
	Reason: string?,
}

export type TRowApplicationResult = {
	RowCount: number,
	AppliedCount: number,
	InvalidRowCount: number,
	UnresolvedCount: number,
	SkippedCount: number,
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

export type TManagedJob = {
	Dispatch: (self: TManagedJob, payload: any) -> TManagedJobDispatchStatus,
	PollCompleted: (self: TManagedJob, currentSessionToken: any?) -> TManagedJobResult?,
	HasInFlight: (self: TManagedJob) -> boolean,
	GetStatus: (self: TManagedJob) -> TManagedJobStatus,
	Reset: (self: TManagedJob) -> (),
	Destroy: (self: TManagedJob) -> (),
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
	CreateManagedJob: (self: TRunner, config: TManagedJobConfig) -> TManagedJob,
	SetSharedMemory: (self: TRunner, jobName: string, sharedMemory: SharedTable?) -> TResult<boolean>,
	Run: (self: TRunner, request: TRunRequest) -> TResult<TRunnerRunHandle>,
	RunAsync: (self: TRunner, request: TRunRequest) -> TResult<TRunPromise>,
	Destroy: (self: TRunner) -> TResult<boolean>,
}

local Types = {}

return Types
