--!strict

--[=[
	@class BaseExecutorEntry
	Entry-point module that forwards to `BaseExecutor`.
	@server
	@client
]=]

local BaseExecutor = require(script.src)
local Types = require(script.src.Types)

export type TExecutorConfig = Types.TExecutorConfig
export type TEntityState = Types.TEntityState
export type TGuard = Types.TGuard
export type TAsyncCleanup = Types.TAsyncCleanup
export type TTrackedAsyncResource = Types.TTrackedAsyncResource
export type TPromiseStatus = Types.TPromiseStatus
export type TPromiseOptions = Types.TPromiseOptions
export type TPromiseState = Types.TPromiseState
export type TCursorState = Types.TCursorState
export type TQueueTurnResult = Types.TQueueTurnResult
export type TQueueRunResult = Types.TQueueRunResult
export type TExecutorQueueItem = Types.TExecutorQueueItem
export type TExecutorQueueConfig = Types.TExecutorQueueConfig
export type TExecutorQueueSnapshot = Types.TExecutorQueueSnapshot
export type TBaseExecutor = BaseExecutor.TBaseExecutor

return BaseExecutor
