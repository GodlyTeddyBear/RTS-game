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

return table.freeze({})
