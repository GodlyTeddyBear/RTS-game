--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local EntityRuntimeParticipationPolicy = {}
EntityRuntimeParticipationPolicy.__index = EntityRuntimeParticipationPolicy

function EntityRuntimeParticipationPolicy.new()
	return setmetatable({}, EntityRuntimeParticipationPolicy)
end

function EntityRuntimeParticipationPolicy:Init(_registry: any, _name: string)
	return
end

function EntityRuntimeParticipationPolicy:RequireBindingParticipation(
	runtimeParticipation: any,
	entity: number
): Result.Result<boolean>
	local featureName = runtimeParticipation:GetFeatureName(entity)
	if featureName == nil then
		return Result.Err("UnknownRuntimeEntity", Errors.UNKNOWN_RUNTIME_ENTITY, {
			Entity = entity,
		})
	end

	if not runtimeParticipation:IsFeatureEnabled("Binding", featureName) then
		return Result.Err("FeatureRuntimeNotEnabled", Errors.FEATURE_RUNTIME_NOT_ENABLED, {
			Entity = entity,
			FeatureName = featureName,
			Mode = "Binding",
		})
	end

	return Result.Ok(true)
end

function EntityRuntimeParticipationPolicy:ShouldRegisterReplication(runtimeParticipation: any, entity: number): boolean
	local featureName = runtimeParticipation:GetFeatureName(entity)
	return featureName ~= nil and runtimeParticipation:IsFeatureEnabled("Replication", featureName)
end

return EntityRuntimeParticipationPolicy
