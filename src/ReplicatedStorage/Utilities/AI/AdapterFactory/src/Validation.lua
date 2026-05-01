--!strict

local Types = require(script.Parent.Types)
local ConfigPolicy = require(script.Parent.ConfigPolicy)
local HasValidActionStateShapeSpec = require(script.Parent.Specs.HasValidActionStateShapeSpec)

type TConfig = Types.TConfig
type TFactoryConfig = Types.TFactoryConfig

--[=[
	@class AiAdapterFactoryValidation
	Centralizes adapter-builder validation for direct callbacks and factory-backed surfaces.
	@server
	@client
]=]

local Validation = {}

-- Direct callback adapters
function Validation.ValidateConfig(config: TConfig)
	ConfigPolicy.ValidateDirectConfig(config)
end

-- Factory-backed adapters
function Validation.ResolveFactoryConfig(config: TFactoryConfig): TConfig
	return ConfigPolicy.ResolveFactoryConfig(config)
end

function Validation.ValidateAdapter(adapter: Types.TActorAdapter)
	assert(type(adapter) == "table", "AiAdapterFactory built adapter must be a table")

	for _, callbackName in ipairs(ConfigPolicy.GetRequiredCallbacks()) do
		assert(
			type((adapter :: any)[callbackName]) == "function",
			("AiAdapterFactory built adapter.%s must be a function"):format(callbackName)
		)
	end

	if (adapter :: any).GetActorLabel ~= nil then
		assert(type((adapter :: any).GetActorLabel) == "function", "AiAdapterFactory built adapter.GetActorLabel must be a function")
	end
end

function Validation.ValidateQueryActiveEntitiesResult(entities: any)
	assert(type(entities) == "table", "AiAdapterFactory QueryActiveEntities must return an array")
end

function Validation.ValidateActionState(actionState: any, sourceLabel: string)
	local result = HasValidActionStateShapeSpec.HasValidActionStateShape:IsSatisfiedBy({
		ActionState = actionState,
	})
	assert(result.success, ("%s received an invalid action-state payload"):format(sourceLabel))
end

function Validation.ValidateShouldEvaluateResult(result: any)
	assert(type(result) == "boolean", "AiAdapterFactory ShouldEvaluate must return a boolean")
end

return table.freeze(Validation)
