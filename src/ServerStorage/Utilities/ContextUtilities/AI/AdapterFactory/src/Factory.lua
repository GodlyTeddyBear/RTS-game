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
			local entities = config.QueryActiveEntities(frameContext)
			Validation.ValidateQueryActiveEntitiesResult(entities)
			return entities
		end,
		GetCompiledBehaviorTree = function(_self: TActorAdapter, entity: number): any?
			return config.GetCompiledBehaviorTree(entity)
		end,
		GetActionState = function(_self: TActorAdapter, entity: number): TActionState?
			local actionState = config.GetActionState(entity)
			Validation.ValidateActionState(actionState, "AiAdapterFactory GetActionState")
			return actionState
		end,
		SetActionState = function(_self: TActorAdapter, entity: number, actionState: TActionState)
			Validation.ValidateActionState(actionState, "AiAdapterFactory SetActionState")
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
			local shouldEvaluate = config.ShouldEvaluate(entity, currentTime)
			Validation.ValidateShouldEvaluateResult(shouldEvaluate)
			return shouldEvaluate
		end,
	} :: TActorAdapter

	if config.ActorLabel ~= nil then
		(adapter :: any).GetActorLabel = function(_self: TActorAdapter): string?
			return config.ActorLabel
		end
	end

	Validation.ValidateAdapter(adapter)

	return adapter
end

--[=[
	Creates one factory-backed adapter for `AiRuntime`.
	@within AiAdapterFactoryImpl
	@param config TFactoryConfig
	@return TActorAdapter
]=]
function Factory.CreateFactory(config: TFactoryConfig): TActorAdapter
	return Factory.Create(Validation.ResolveFactoryConfig(config))
end

return table.freeze(Factory)
