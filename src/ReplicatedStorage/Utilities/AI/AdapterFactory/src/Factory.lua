--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TActionState = Types.TActionState
type TActorAdapter = Types.TActorAdapter
type TConfig = Types.TConfig

local Factory = {}

function Factory.Create(config: TConfig): TActorAdapter
	Validation.ValidateConfig(config)

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

return table.freeze(Factory)
