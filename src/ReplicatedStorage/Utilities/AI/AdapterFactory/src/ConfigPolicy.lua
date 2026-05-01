--!strict

local Types = require(script.Parent.Types)
local HasRequiredCallbacksSpec = require(script.Parent.Specs.HasRequiredCallbacksSpec)
local HasResolvableFactorySurfacesSpec = require(script.Parent.Specs.HasResolvableFactorySurfacesSpec)
local HasValidActorLabelSpec = require(script.Parent.Specs.HasValidActorLabelSpec)

type TConfig = Types.TConfig
type TFactoryConfig = Types.TFactoryConfig

local REQUIRED_CALLBACKS = table.freeze({
	"QueryActiveEntities",
	"GetCompiledBehaviorTree",
	"GetActionState",
	"SetActionState",
	"ClearActionState",
	"SetPendingAction",
	"UpdateLastTickTime",
	"ShouldEvaluate",
})

local ConfigPolicy = {}

local function _AssertSatisfied(result: any, message: string)
	assert(result.success, message)
end

function ConfigPolicy.GetRequiredCallbacks(): { string }
	return REQUIRED_CALLBACKS
end

function ConfigPolicy.ValidateDirectConfig(config: TConfig)
	assert(type(config) == "table", "AiAdapterFactory config must be a table")

	_AssertSatisfied(
		HasValidActorLabelSpec.HasValidActorLabel:IsSatisfiedBy({
			ActorLabel = config.ActorLabel,
		}),
		"AiAdapterFactory ActorLabel must be a non-empty string"
	)

	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		_AssertSatisfied(
			HasRequiredCallbacksSpec.HasFunctionCallback:IsSatisfiedBy({
				ConfigLabel = "AiAdapterFactory config",
				CallbackName = callbackName,
				CallbackValue = (config :: any)[callbackName],
			}),
			("AiAdapterFactory config.%s must be a function"):format(callbackName)
		)
	end
end

function ConfigPolicy.ResolveFactoryConfig(config: TFactoryConfig): TConfig
	assert(type(config) == "table", "AiAdapterFactory factory config must be a table")
	assert(config.Factory ~= nil, "AiAdapterFactory factory config.Factory is required")

	_AssertSatisfied(
		HasValidActorLabelSpec.HasValidActorLabel:IsSatisfiedBy({
			ActorLabel = config.ActorLabel,
		}),
		"AiAdapterFactory ActorLabel must be a non-empty string"
	)

	local factoryObject = config.Factory
	local resolvedSurfaces = {}

	for _, surfaceName in ipairs(REQUIRED_CALLBACKS) do
		local surfaceValue = (config :: any)[surfaceName]
		_AssertSatisfied(
			HasResolvableFactorySurfacesSpec.HasSupportedFactorySurfaceType:IsSatisfiedBy({
				SurfaceName = surfaceName,
				SurfaceValue = surfaceValue,
			}),
			("AiAdapterFactory factory config.%s must be a method-name string or function"):format(surfaceName)
		)

		if type(surfaceValue) == "string" then
			local methodName = surfaceValue
			local methodValue = factoryObject[methodName]
			_AssertSatisfied(
				HasResolvableFactorySurfacesSpec.HasResolvableFactoryMethod:IsSatisfiedBy({
					MethodName = methodName,
					MethodValue = methodValue,
					SurfaceName = surfaceName,
				}),
				("AiAdapterFactory factory is missing method '%s' for surface '%s'"):format(methodName, surfaceName)
			)

			resolvedSurfaces[surfaceName] = function(...: any): ...any
				return methodValue(factoryObject, ...)
			end
		else
			local callback = surfaceValue :: (any, ...any) -> ...any
			resolvedSurfaces[surfaceName] = function(...: any): ...any
				return callback(factoryObject, ...)
			end
		end
	end

	local resolvedConfig = {
		ActorLabel = config.ActorLabel,
		QueryActiveEntities = resolvedSurfaces.QueryActiveEntities,
		GetCompiledBehaviorTree = resolvedSurfaces.GetCompiledBehaviorTree,
		GetActionState = resolvedSurfaces.GetActionState,
		SetActionState = resolvedSurfaces.SetActionState,
		ClearActionState = resolvedSurfaces.ClearActionState,
		SetPendingAction = resolvedSurfaces.SetPendingAction,
		UpdateLastTickTime = resolvedSurfaces.UpdateLastTickTime,
		ShouldEvaluate = resolvedSurfaces.ShouldEvaluate,
	}

	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		_AssertSatisfied(
			HasRequiredCallbacksSpec.HasFunctionCallback:IsSatisfiedBy({
				ConfigLabel = "AiAdapterFactory resolved config",
				CallbackName = callbackName,
				CallbackValue = (resolvedConfig :: any)[callbackName],
			}),
			("AiAdapterFactory resolved config.%s must be a function"):format(callbackName)
		)
	end

	return resolvedConfig
end

return table.freeze(ConfigPolicy)
