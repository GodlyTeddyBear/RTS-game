--!strict

local Types = require(script.Parent.Types)

type TConfig = Types.TConfig
type TFactoryConfig = Types.TFactoryConfig

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

local REQUIRED_FACTORY_SURFACES = REQUIRED_CALLBACKS

--[=[
	@class AiAdapterFactoryValidation
	Centralizes adapter-builder validation for direct callbacks and factory-backed surfaces.
	@server
	@client
]=]

local Validation = {}

-- Direct callback adapters
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

-- Factory-backed adapters
function Validation.ValidateFactoryConfig(config: TFactoryConfig)
	assert(type(config) == "table", "AiAdapterFactory factory config must be a table")
	assert(config.Factory ~= nil, "AiAdapterFactory factory config.Factory is required")

	if config.ActorLabel ~= nil then
		assert(type(config.ActorLabel) == "string" and #config.ActorLabel > 0, "AiAdapterFactory ActorLabel must be a non-empty string")
	end

	for _, surfaceName in ipairs(REQUIRED_FACTORY_SURFACES) do
		local surface = (config :: any)[surfaceName]
		local surfaceType = type(surface)
		assert(
			surfaceType == "string" or surfaceType == "function",
			("AiAdapterFactory factory config.%s must be a method-name string or function"):format(surfaceName)
		)
	end
end

return table.freeze(Validation)
