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
export type TBaseExecutor = BaseExecutor.TBaseExecutor

return BaseExecutor
