--!strict

local Types = require(script.Parent.Types)

type TConfig = Types.TConfig

local REQUIRED_CALLBACKS = table.freeze({
	"QueryActiveEntities",
	"GetBehaviorTree",
	"GetActionState",
	"SetActionState",
	"ClearActionState",
	"SetPendingAction",
	"UpdateLastTickTime",
	"ShouldEvaluate",
})

local Validation = {}

function Validation.ValidateConfig(config: TConfig)
	assert(type(config) == "table", "AiAdapterFactory config must be a table")

	if config.ActorLabel ~= nil then
		assert(type(config.ActorLabel) == "string" and #config.ActorLabel > 0, "AiAdapterFactory ActorLabel must be a non-empty string")
	end

	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		assert(
			type((config :: any)[callbackName]) == "function",
			("AiAdapterFactory config.%s must be a function"):format(callbackName)
		)
	end
end

return table.freeze(Validation)
