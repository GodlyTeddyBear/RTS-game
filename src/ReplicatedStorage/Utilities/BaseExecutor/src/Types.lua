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

export type TGuard = {
	Check: (entity: number, services: any) -> boolean,
	Reason: string,
}

export type TAsyncCleanup = ((resource: any) -> ()) | string

export type TTrackedAsyncResource = {
	Resource: any,
	Cleanup: TAsyncCleanup?,
}

return table.freeze({})
