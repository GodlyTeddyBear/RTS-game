--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScratchRecycler = require(ReplicatedStorage.Utilities.AI.src.Infrastructure.ScratchRecycler)
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

local function _CreateCandidateMap()
	return ScratchRecycler.AcquireMap()
end

local function _ReleaseCandidateMap(candidate: { [any]: any })
	ScratchRecycler.ReleaseMap(candidate)
end

function ConfigPolicy.GetRequiredCallbacks(): { string }
	return REQUIRED_CALLBACKS
end

function ConfigPolicy.ValidateDirectConfig(config: TConfig)
	assert(type(config) == "table", "AiAdapterFactory config must be a table")

	local actorLabelCandidate = _CreateCandidateMap()
	actorLabelCandidate.ActorLabel = config.ActorLabel

	local actorLabelResult = HasValidActorLabelSpec.HasValidActorLabel:IsSatisfiedBy(actorLabelCandidate)
	_ReleaseCandidateMap(actorLabelCandidate)
	_AssertSatisfied(
		actorLabelResult,
		"AiAdapterFactory ActorLabel must be a non-empty string"
	)

	for _, callbackName in ipairs(REQUIRED_CALLBACKS) do
		local callbackCandidate = _CreateCandidateMap()
		callbackCandidate.ConfigLabel = "AiAdapterFactory config"
		callbackCandidate.CallbackName = callbackName
		callbackCandidate.CallbackValue = (config :: any)[callbackName]

		local callbackResult = HasRequiredCallbacksSpec.HasFunctionCallback:IsSatisfiedBy(callbackCandidate)
		_ReleaseCandidateMap(callbackCandidate)
		_AssertSatisfied(
			callbackResult,
			("AiAdapterFactory config.%s must be a function"):format(callbackName)
		)
	end
end

function ConfigPolicy.ResolveFactoryConfig(config: TFactoryConfig): TConfig
	assert(type(config) == "table", "AiAdapterFactory factory config must be a table")
	assert(config.Factory ~= nil, "AiAdapterFactory factory config.Factory is required")

	local actorLabelCandidate = _CreateCandidateMap()
	actorLabelCandidate.ActorLabel = config.ActorLabel

	local actorLabelResult = HasValidActorLabelSpec.HasValidActorLabel:IsSatisfiedBy(actorLabelCandidate)
	_ReleaseCandidateMap(actorLabelCandidate)
	_AssertSatisfied(
		actorLabelResult,
		"AiAdapterFactory ActorLabel must be a non-empty string"
	)

	local factoryObject = config.Factory
	local resolvedSurfaces = {}

	for _, surfaceName in ipairs(REQUIRED_CALLBACKS) do
		local surfaceValue = (config :: any)[surfaceName]
		local surfaceTypeCandidate = _CreateCandidateMap()
		surfaceTypeCandidate.SurfaceName = surfaceName
		surfaceTypeCandidate.SurfaceValue = surfaceValue

		local surfaceTypeResult = HasResolvableFactorySurfacesSpec.HasSupportedFactorySurfaceType:IsSatisfiedBy(
			surfaceTypeCandidate
		)
		_ReleaseCandidateMap(surfaceTypeCandidate)
		_AssertSatisfied(
			surfaceTypeResult,
			("AiAdapterFactory factory config.%s must be a method-name string or function"):format(surfaceName)
		)

		if type(surfaceValue) == "string" then
			local methodName = surfaceValue
			local methodValue = factoryObject[methodName]
			local methodCandidate = _CreateCandidateMap()
			methodCandidate.MethodName = methodName
			methodCandidate.MethodValue = methodValue
			methodCandidate.SurfaceName = surfaceName

			local methodResult = HasResolvableFactorySurfacesSpec.HasResolvableFactoryMethod:IsSatisfiedBy(methodCandidate)
			_ReleaseCandidateMap(methodCandidate)
			_AssertSatisfied(
				methodResult,
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
		local callbackCandidate = _CreateCandidateMap()
		callbackCandidate.ConfigLabel = "AiAdapterFactory resolved config"
		callbackCandidate.CallbackName = callbackName
		callbackCandidate.CallbackValue = (resolvedConfig :: any)[callbackName]

		local callbackResult = HasRequiredCallbacksSpec.HasFunctionCallback:IsSatisfiedBy(callbackCandidate)
		_ReleaseCandidateMap(callbackCandidate)
		_AssertSatisfied(
			callbackResult,
			("AiAdapterFactory resolved config.%s must be a function"):format(callbackName)
		)
	end

	return resolvedConfig
end

return table.freeze(ConfigPolicy)
