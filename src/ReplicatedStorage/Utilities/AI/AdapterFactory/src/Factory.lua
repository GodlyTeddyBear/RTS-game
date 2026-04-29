--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TActionState = Types.TActionState
type TActorAdapter = Types.TActorAdapter
type TConfig = Types.TConfig
type TFactoryConfig = Types.TFactoryConfig

--[=[
	@class AiAdapterFactoryImpl
	Builds runtime adapter tables from explicit callbacks or from method-name surfaces on one factory object.
	@server
	@client
]=]

local Factory = {}

local function _BuildFactoryInvoker(factoryObject: any, surface: any): (...any) -> ...any
	-- Method-name strings let callers wire existing factory APIs without wrapping every call site.
	if type(surface) == "string" then
		return function(...: any): ...any
			local method = factoryObject[surface]
			assert(type(method) == "function", ("AiAdapterFactory factory is missing method '%s'"):format(surface))
			return method(factoryObject, ...)
		end
	end

	return function(...: any): ...any
		return surface(factoryObject, ...)
	end
end

--[=[
	Creates one direct callback adapter for `AiRuntime`.
	@within AiAdapterFactoryImpl
	@param config TConfig
	@return TActorAdapter
]=]
function Factory.Create(config: TConfig): TActorAdapter
	Validation.ValidateConfig(config)

	-- The returned adapter is a plain table so the runtime can call it without owning any state.
	local adapter = {
		QueryActiveEntities = function(_self: TActorAdapter, frameContext: any): { number }
			return config.QueryActiveEntities(frameContext)
		end,
		GetBehaviorTree = function(_self: TActorAdapter, entity: number): any?
			return config.GetBehaviorTree(entity)
		end,
		GetActionState = function(_self: TActorAdapter, entity: number): TActionState?
			return config.GetActionState(entity)
		end,
		SetActionState = function(_self: TActorAdapter, entity: number, actionState: TActionState)
			config.SetActionState(entity, actionState)
		end,
		ClearActionState = function(_self: TActorAdapter, entity: number)
			config.ClearActionState(entity)
		end,
		SetPendingAction = function(_self: TActorAdapter, entity: number, actionId: string, actionData: any?)
			config.SetPendingAction(entity, actionId, actionData)
		end,
		UpdateLastTickTime = function(_self: TActorAdapter, entity: number, currentTime: number)
			config.UpdateLastTickTime(entity, currentTime)
		end,
		ShouldEvaluate = function(_self: TActorAdapter, entity: number, currentTime: number): boolean
			return config.ShouldEvaluate(entity, currentTime)
		end,
	} :: TActorAdapter

	if config.ActorLabel ~= nil then
		(adapter :: any).GetActorLabel = function(_self: TActorAdapter): string?
			return config.ActorLabel
		end
	end

	return adapter
end

--[=[
	Creates one factory-backed adapter for `AiRuntime`.
	@within AiAdapterFactoryImpl
	@param config TFactoryConfig
	@return TActorAdapter
]=]
function Factory.CreateFactory(config: TFactoryConfig): TActorAdapter
	Validation.ValidateFactoryConfig(config)

	local factoryObject = config.Factory

	-- Factory-backed adapters forward through the same explicit callback contract as direct adapters.
	return Factory.Create({
		ActorLabel = config.ActorLabel,
		QueryActiveEntities = _BuildFactoryInvoker(factoryObject, config.QueryActiveEntities),
		GetBehaviorTree = _BuildFactoryInvoker(factoryObject, config.GetBehaviorTree),
		GetActionState = _BuildFactoryInvoker(factoryObject, config.GetActionState),
		SetActionState = _BuildFactoryInvoker(factoryObject, config.SetActionState),
		ClearActionState = _BuildFactoryInvoker(factoryObject, config.ClearActionState),
		SetPendingAction = _BuildFactoryInvoker(factoryObject, config.SetPendingAction),
		UpdateLastTickTime = _BuildFactoryInvoker(factoryObject, config.UpdateLastTickTime),
		ShouldEvaluate = _BuildFactoryInvoker(factoryObject, config.ShouldEvaluate),
	})
end

return table.freeze(Factory)
