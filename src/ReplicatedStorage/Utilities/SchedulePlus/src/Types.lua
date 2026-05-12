--!strict

--[=[
	@class SchedulePlusTypes
	Shared type aliases for the `SchedulePlus` package surface.
]=]

export type TCancelableHandle = {
	Cancel: (self: TCancelableHandle) -> (),
	Destroy: (self: TCancelableHandle) -> (),
	IsCancelled: (self: TCancelableHandle) -> boolean,
	IsPending: (self: TCancelableHandle) -> boolean,
	IsRunning: (self: TCancelableHandle) -> boolean,
	IsCompleted: (self: TCancelableHandle) -> boolean,
}

export type TExecutionHandle = TCancelableHandle & {
	Flush: ((self: TExecutionHandle) -> ())?,
	Pause: ((self: TExecutionHandle) -> ())?,
	Resume: ((self: TExecutionHandle) -> ())?,
	IsPaused: ((self: TExecutionHandle) -> boolean)?,
}

export type TScope = {
	Add: (self: TScope, handle: any) -> any,
	CancelAll: (self: TScope) -> (),
	PauseAll: (self: TScope) -> (),
	ResumeAll: (self: TScope) -> (),
	Destroy: (self: TScope) -> (),
	GetCount: (self: TScope) -> number,
}

export type TRateLimitConfig = {
	Delay: number,
	Leading: boolean?,
	Trailing: boolean?,
}

export type TDelayUntilConfig = {
	Callback: (() -> ())?,
	PollInterval: number?,
	TimeoutSeconds: number?,
}

export type TTickWhenConfig = {
	Frequency: number?,
	Predicate: (...any) -> boolean,
	Callback: (...any) -> (),
}

export type TQueueConfig<T> = {
	FlushMode: "Defer" | "Timer" | "Manual",
	FlushInterval: number?,
	MaxBatchSize: number?,
	MaxQueueSize: number?,
	OverflowPolicy: "Grow" | "DropNewest" | "DropOldest" | "Reject"?,
	Coalesce: ((existingBatch: { T }, newItem: T) -> boolean)?,
	OnFlush: ({ T }) -> (),
}

export type TQueue<T> = {
	FlushMode: "Defer" | "Timer" | "Manual",
	FlushInterval: number?,
	MaxBatchSize: number?,
	MaxQueueSize: number?,
	OverflowPolicy: "Grow" | "DropNewest" | "DropOldest" | "Reject",
	Coalesce: ((existingBatch: { T }, newItem: T) -> boolean)?,
	OnFlush: ({ T }) -> (),
	Add: (self: TQueue<T>, item: T) -> boolean,
	Flush: (self: TQueue<T>) -> (),
	Clear: (self: TQueue<T>) -> (),
	Destroy: (self: TQueue<T>) -> (),
	Pause: (self: TQueue<T>) -> (),
	Resume: (self: TQueue<T>) -> (),
	IsPaused: (self: TQueue<T>) -> boolean,
	IsScheduled: (self: TQueue<T>) -> boolean,
	GetSize: (self: TQueue<T>) -> number,
}

export type TSerialQueueConfig<T> = {
	Worker: ((item: T) -> ())?,
	AutoStart: boolean?,
}

export type TSerialQueue<T> = {
	Add: (self: TSerialQueue<T>, item: T, workerCallback: ((item: T) -> ())?) -> (),
	Start: (self: TSerialQueue<T>) -> (),
	Stop: (self: TSerialQueue<T>) -> (),
	Clear: (self: TSerialQueue<T>) -> (),
	Destroy: (self: TSerialQueue<T>) -> (),
	IsRunning: (self: TSerialQueue<T>) -> boolean,
}

export type TPriorityQueueConfig<T> = {
	OnFlush: ({ T }) -> (),
	HighestFirst: boolean?,
}

export type TPriorityQueue<T> = {
	Add: (self: TPriorityQueue<T>, item: T, priority: number) -> (),
	Flush: (self: TPriorityQueue<T>) -> (),
	Clear: (self: TPriorityQueue<T>) -> (),
	Destroy: (self: TPriorityQueue<T>) -> (),
}

export type TJob<T...> = (T...) -> ()

export type TScheduleConfig<T...> = {
	Before: ((job: TJob<T...>, T...) -> ())?,
	After: ((job: TJob<T...>, T...) -> ())?,
}

export type TSchedule<T...> = {
	Graph: { [TJob<T...>]: { TJob<T...> } },
	Jobs: { TJob<T...> },
	Before: ((job: TJob<T...>, T...) -> ())?,
	After: ((job: TJob<T...>, T...) -> ())?,
	Job: (self: TSchedule<T...>, callback: TJob<T...>, ...TJob<T...>) -> TJob<T...>,
	Run: (self: TSchedule<T...>, T...) -> (),
	Validate: (self: TSchedule<T...>) -> (boolean, string?),
	Clear: (self: TSchedule<T...>) -> (),
	GetJobs: (self: TSchedule<T...>) -> { TJob<T...> },
	HasJob: (self: TSchedule<T...>, callback: TJob<T...>) -> boolean,
}

export type TPipelineStage<TContext> = {
	Name: string,
	Callback: (context: TContext) -> (),
}

export type TPipelineConfig<TContext> = {
	Stages: { TPipelineStage<TContext> }?,
}

export type TPipeline<TContext> = {
	AddStage: (self: TPipeline<TContext>, name: string, callback: (context: TContext) -> ()) -> (),
	Run: (self: TPipeline<TContext>, context: TContext) -> (),
	Clear: (self: TPipeline<TContext>) -> (),
	GetStageNames: (self: TPipeline<TContext>) -> { string },
}

export type TSequenceStep = {
	DelaySeconds: number?,
	Callback: () -> (),
}

export type TSequence = TExecutionHandle & {
	Start: (self: TSequence) -> (),
}

export type TDebounceEntry = {
	Handle: TExecutionHandle,
}

export type TCancelable = TCancelableHandle

local Types = {}

return Types
