--!strict

local Types = require(script.Types)

export type TBaseExecutor = {
	Config: Types.TExecutorConfig,
	_entityState: { [number]: Types.TEntityState },
	_trackedAsyncResources: { [number]: { [string]: Types.TTrackedAsyncResource } },
	_promiseState: { [number]: Types.TPromiseSlotMap },
	_cursorState: { [number]: Types.TCursorSlotMap },
	_queueState: { [string]: Types.TExecutorQueueState },
	_cursorAdvanceGate: Types.TCursorAdvanceGateMap,
	_entityGeneration: Types.TEntityGenerationMap,
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
local PromiseStateComposer: TComposer = require(script.Public.PromiseState)
local CursorStateComposer: TComposer = require(script.Public.CursorState)
local QueueStateComposer: TComposer = require(script.Public.QueueState)
local TickHelpersComposer: TComposer = require(script.Public.TickHelpers)
local LifecycleComposer: TComposer = require(script.Public.Lifecycle)

local BaseExecutor: TBaseExecutorStatic = {} :: TBaseExecutorStatic
BaseExecutor.__index = BaseExecutor

StatusComposer(BaseExecutor)
GuardsComposer(BaseExecutor)
EntityStateComposer(BaseExecutor)
AsyncResourcesComposer(BaseExecutor)
PromiseStateComposer(BaseExecutor)
CursorStateComposer(BaseExecutor)
QueueStateComposer(BaseExecutor)
TickHelpersComposer(BaseExecutor)
LifecycleComposer(BaseExecutor)

return BaseExecutor
