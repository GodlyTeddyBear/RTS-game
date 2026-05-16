--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

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

export type TOperationRow = { [string]: any } | { any }

export type TOperationDefinition = {
	Name: string,
	ResultSchema: { TResultField }?,
	GetResultSchema: ((operationConfig: any?) -> { TResultField })?,
	CacheLocalMemory: boolean?,
	Execute: (taskId: number, memory: SharedTable?, ...any) -> TOperationRow,
	InitialLocalMemory: SharedTable?,
}

export type TStaticOperationDefinition = TOperationDefinition & {
	BuildEmptyRow: (self: TStaticOperationDefinition, overrides: { [string]: any }?) -> { [string]: any },
}

export type TParallelQueryError = {
	Kind: "WorkerError" | "Timeout",
	OperationName: string,
	Message: string,
	TaskIds: { number }?,
	TimeoutSeconds: number?,
	Traceback: string?,
}

export type TParallelQueryConfig = {
	Name: string?,
	ActorCount: number,
	ActorParent: Instance?,
	Operations: { ModuleScript },
	OperationConfigs: { [string]: any }?,
}

export type TRunRequest = {
	WorkCount: number,
	BatchSize: number?,
	Arguments: { any }?,
	TimeoutSeconds: number?,
}

export type TSharedMemoryScalar = Vector2 | Vector3 | CFrame | Color3 | UDim | UDim2 | number | boolean | string | buffer
export type TSharedMemoryArray = { [number]: TSharedMemoryScalar }
export type TSharedMemoryFieldValue = TSharedMemoryScalar | TSharedMemoryArray
export type TSharedMemoryFieldMap = { [string]: TSharedMemoryFieldValue }
export type TSharedMemorySnapshotBuilder = {
	Fields: TSharedMemoryFieldMap,
	ArrayLengths: { [string]: number },
}

export type TManagedAsyncResult = {
	RequestId: number,
	SessionToken: any?,
	Payload: any?,
	Rows: { [string]: any }?,
	Err: any?,
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

export type TManagedJobPolicyPreset = "StrictFreshOnly" | "KeepLastGood" | "ApplyFreshOrMarkFallback"
export type TManagedJobPolicyConfig = {
	Preset: TManagedJobPolicyPreset,
}

export type TManagedJobDispatchStatus = TManagedDispatchStatus
export type TManagedJobConfig = {
	OperationName: string,
	BuildLocalMemory: (payload: any) -> SharedTable,
	BuildRunRequest: (payload: any) -> TRunRequest,
	GetSessionToken: ((payload: any) -> any?)?,
	MaxInFlightSeconds: number?,
	Policy: (TManagedJobPolicyPreset | TManagedJobPolicyConfig)?,
}
export type TManagedJobResult = TManagedAsyncResult & {
	PolicyStatus: "Fresh" | "Fallback",
	FallbackReason: "PreviousGood" | "Error" | "Timeout"?,
}

export type TManagedJobStatus = {
	InFlight: boolean,
	LastDispatchClock: number,
	HasCompletedResult: boolean,
	HasLastGoodResult: boolean,
	NeedsFallback: boolean,
	FallbackReason: "PreviousGood" | "Error" | "Timeout"?,
	PolicyPreset: TManagedJobPolicyPreset,
	LastError: any?,
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

export type TMemoryFieldValidationResult = {
	IsValid: boolean,
	FieldName: string?,
	Reason: string?,
}

export type TRowApplicationResult = {
	RowCount: number,
	AppliedCount: number,
	InvalidRowCount: number,
	UnresolvedCount: number,
	SkippedCount: number,
}

export type TReductionSummary = {
	RowCount: number,
	ReducedCount: number,
	SkippedCount: number,
	GroupCount: number,
}

export type TParallelQueryProfileCounters = {
	Dispatches: number,
	Completions: number,
	WorkerErrors: number,
	Timeouts: number,
	StaleDrops: number,
	InFlightSkips: number,
	Fallbacks: number,
	DecodedRows: number,
	WorkDispatched: number,
	LastDurationMilliseconds: number,
}

export type TParallelQueryOperationProfileSnapshot = {
	OperationName: string,
	Counters: TParallelQueryProfileCounters,
	LastRowCount: number,
	LastWorkCount: number,
}

export type TParallelQueryProfileSnapshot = {
	Name: string,
	Counters: TParallelQueryProfileCounters,
	Operations: { [string]: TParallelQueryOperationProfileSnapshot },
}

export type TManagedJobProfileSnapshot = {
	OperationName: string,
	Counters: TParallelQueryProfileCounters,
}

export type TManagedJob = {
	Dispatch: (self: TManagedJob, payload: any) -> TManagedJobDispatchStatus,
	PollCompleted: (self: TManagedJob, currentSessionToken: any?) -> TManagedJobResult?,
	HasInFlight: (self: TManagedJob) -> boolean,
	GetStatus: (self: TManagedJob) -> TManagedJobStatus,
	GetProfileSnapshot: (self: TManagedJob) -> TManagedJobProfileSnapshot?,
	Reset: (self: TManagedJob) -> (),
	Destroy: (self: TManagedJob) -> (),
}

export type TDispatchHandle = {
	Cancel: (self: TDispatchHandle) -> (),
}

export type TTaskObject = {
	taskName: string,
	packetDef: { any },
	packetBytesNeeded: number,
}

export type TTaskCoordinator = {
	DefineTask: (self: TTaskCoordinator, taskName: string, taskMetaData: { packet: { any }, localMemory: SharedTable? }) -> TTaskObject,
	SetTaskLocalMemory: (self: TTaskCoordinator, taskObject: TTaskObject, newLocalMemory: SharedTable) -> (),
	DispatchTask: (
		self: TTaskCoordinator,
		taskObject: TTaskObject,
		threadCount: number,
		batchSize: number,
		callback: (any) -> (),
		returnMergedRawBuffer: boolean?,
		...any
	) -> TDispatchHandle,
	Destroy: (self: TTaskCoordinator) -> (),
}

export type TRegisteredOperation = {
	CacheLocalMemory: boolean,
	Schema: { TResultField },
	TaskObject: TTaskObject,
	LocalMemory: SharedTable?,
}

export type TParallelQueryRunner = {
	_name: string,
	_actorCount: number,
	_actorStorage: Folder,
	_coordinator: TTaskCoordinator,
	_operations: { [string]: TRegisteredOperation },
	_activeRunCounts: { [string]: number },
	_managedJobs: { [TManagedJob]: boolean },
	_destroyed: boolean,

	Run: (
		self: TParallelQueryRunner,
		operationName: string,
		request: TRunRequest,
		onComplete: ({ [string]: any }?, TParallelQueryError?) -> ()
	) -> (),
	RunAsync: (
		self: TParallelQueryRunner,
		operationName: string,
		request: TRunRequest
	) -> typeof(Promise.new(function() end)),
	CreateManagedJob: (self: TParallelQueryRunner, config: TManagedJobConfig) -> TManagedJob,
	GetProfileSnapshot: (self: TParallelQueryRunner) -> TParallelQueryProfileSnapshot?,
	EmitProfileSummary: (self: TParallelQueryRunner, force: boolean?) -> (),
	SetLocalMemory: (self: TParallelQueryRunner, operationName: string, sharedMemory: SharedTable) -> (),
	Destroy: (self: TParallelQueryRunner) -> (),
}

return nil
