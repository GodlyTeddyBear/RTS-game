--!strict

export type TExecutorConfig = {
	ActionId: string,
	IsCommitted: boolean,
	Duration: number?,
	AutoCleanupOnComplete: boolean?,
}

export type TEntityState = {
	[string]: any,
}

export type TEntityGenerationMap = {
	[number]: number,
}

export type TCursorAdvanceGateMap = {
	[number]: { [string]: boolean },
}

export type TGuard = {
	Check: (entity: number, services: any) -> boolean,
	Reason: string,
}

export type TAsyncCleanup = ((resource: any) -> ()) | string

export type TTrackedAsyncResource = {
	Resource: any,
	Cleanup: TAsyncCleanup?,
}

export type TPromiseStatus = "Idle" | "Pending" | "Resolved" | "Rejected" | "Cancelled"

export type TPromiseOptions = {
	StartedAt: number?,
	TimeoutAt: number?,
	TimeoutSeconds: number?,
	TimeoutError: any?,
}

export type TPromiseState = {
	Promise: any,
	Generation: number,
	Status: TPromiseStatus,
	Result: any?,
	Error: any?,
	StartedAt: number?,
	TimeoutAt: number?,
	TimeoutError: any?,
}

export type TCursorState = {
	Phase: string,
	Index: number,
	BatchSize: number,
	IsDone: boolean,
	Data: { [string]: any },
	Meta: { [string]: any },
	Result: any?,
	[string]: any,
}

export type TPromiseSlotMap = {
	[string]: TPromiseState,
}

export type TCursorSlotMap = {
	[string]: TCursorState,
}

export type TQueueTurnResult = "Granted" | "Queued" | "Dropped"
export type TQueueRunResult = string

export type TExecutorQueueItem = {
	Entity: number,
	Metadata: any?,
	Generation: number,
	EnqueuedAt: number?,
}

export type TExecutorQueueConfig = {
	CapacityPerTick: number,
}

export type TExecutorQueueSnapshot = {
	QueueKey: string,
	CapacityPerTick: number,
	QueuedCount: number,
	FlushedPendingEntities: { number },
	BufferedQueuedCount: number,
	GrantedCountThisTick: number,
	LastServicedTickId: number?,
}

export type TExecutorQueueState = {
	Queue: any,
	CapacityPerTick: number,
	Membership: { [number]: boolean },
	MetadataByEntity: { [number]: any },
	PendingBatch: { TExecutorQueueItem },
	GrantedItemsByEntity: { [number]: TExecutorQueueItem },
	DroppedReasonsByEntity: { [number]: string },
	LastServicedTickId: number?,
	GrantedCountThisTick: number,
	HasNewArrivalsSinceLastService: boolean,
}

return table.freeze({})
