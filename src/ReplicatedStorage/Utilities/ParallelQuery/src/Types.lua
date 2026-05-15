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
	SetLocalMemory: (self: TParallelQueryRunner, operationName: string, sharedMemory: SharedTable) -> (),
	Destroy: (self: TParallelQueryRunner) -> (),
}

return nil
