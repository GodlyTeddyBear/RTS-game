--!strict

local Types = require(script.Types)

export type TBaseExecutor = {
	Config: Types.TExecutorConfig,
	_entityState: { [number]: Types.TEntityState },
	_trackedAsyncResources: { [number]: { [string]: Types.TTrackedAsyncResource } },
	_lastFailureReason: { [number]: string },
}

type TBaseExecutorPrototype = {
	[string]: any,
	__index: TBaseExecutorPrototype,
}

type TBaseExecutorStatic = {
	__index: TBaseExecutorStatic,
	new: (config: Types.TExecutorConfig) -> TBaseExecutor,
}

type TComposer = (BaseExecutor: TBaseExecutorPrototype) -> ()

local StatusComposer: TComposer = require(script.Public.Status)
local GuardsComposer: TComposer = require(script.Public.Guards)
local EntityStateComposer: TComposer = require(script.Public.EntityState)
local AsyncResourcesComposer: TComposer = require(script.Public.AsyncResources)
local LifecycleComposer: TComposer = require(script.Public.Lifecycle)

local BaseExecutor: TBaseExecutorStatic = {} :: TBaseExecutorStatic
BaseExecutor.__index = BaseExecutor

StatusComposer(BaseExecutor)
GuardsComposer(BaseExecutor)
EntityStateComposer(BaseExecutor)
AsyncResourcesComposer(BaseExecutor)
LifecycleComposer(BaseExecutor)

return BaseExecutor
