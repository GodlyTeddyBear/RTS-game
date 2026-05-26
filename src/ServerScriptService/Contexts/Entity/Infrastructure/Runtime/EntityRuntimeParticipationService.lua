--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

type TRuntimeMode = "Binding" | "Sync" | "Replication"

local function _CollectSortedKeys(source: { [string]: true }): { string }
	local values = {}
	for key in pairs(source) do
		table.insert(values, key)
	end
	table.sort(values)
	return values
end

local EntityRuntimeParticipationService = {}
EntityRuntimeParticipationService.__index = EntityRuntimeParticipationService

function EntityRuntimeParticipationService.new()
	local self = setmetatable({}, EntityRuntimeParticipationService)
	self._snapshotBuilder = nil
	self._enabledFeaturesByMode = {
		Binding = {},
		Sync = {},
		Replication = {},
	}
	self._featureByEntity = {}
	self._entitiesByFeature = {}
	return self
end

function EntityRuntimeParticipationService:Init(registry: any, _name: string)
	self._snapshotBuilder = registry:Get("EntityRuntimeSnapshotBuilder")
end

function EntityRuntimeParticipationService:EnableFeature(mode: TRuntimeMode, featureName: string): Result.Result<boolean>
	return Result.Catch(function()
		local enabledFeatures = self._enabledFeaturesByMode[mode]
		if enabledFeatures == nil then
			return Result.Err("InvalidRuntimeMode", Errors.INVALID_RUNTIME_MODE, {
				Mode = mode,
				FeatureName = featureName,
			})
		end

		enabledFeatures[featureName] = true
		return Result.Ok(true)
	end, "EntityRuntimeParticipationService:EnableFeature")
end

function EntityRuntimeParticipationService:IsFeatureEnabled(mode: TRuntimeMode, featureName: string): boolean
	local enabledFeatures = self._enabledFeaturesByMode[mode]
	return enabledFeatures ~= nil and enabledFeatures[featureName] == true
end

function EntityRuntimeParticipationService:HasAnyEnabledMode(featureName: string): boolean
	for _, enabledFeatures in pairs(self._enabledFeaturesByMode) do
		if enabledFeatures[featureName] == true then
			return true
		end
	end

	return false
end

function EntityRuntimeParticipationService:RegisterRuntimeEntity(entity: number): Result.Result<string>
	return Result.Catch(function()
		local snapshotResult = self._snapshotBuilder:BuildSnapshot(entity)
		if not snapshotResult.success then
			return snapshotResult
		end

		local featureName = snapshotResult.value.FeatureName
		if not self:HasAnyEnabledMode(featureName) then
			return Result.Err("FeatureRuntimeNotEnabled", Errors.FEATURE_RUNTIME_NOT_ENABLED, {
				Entity = entity,
				FeatureName = featureName,
			})
		end

		local existingFeatureName = self._featureByEntity[entity]
		if existingFeatureName ~= nil then
			if existingFeatureName == featureName then
				return Result.Ok(featureName)
			end

			return Result.Err("DuplicateRuntimeEntity", Errors.DUPLICATE_RUNTIME_ENTITY, {
				Entity = entity,
				ExistingFeatureName = existingFeatureName,
				FeatureName = featureName,
			})
		end

		self._featureByEntity[entity] = featureName
		local featureEntities = self._entitiesByFeature[featureName]
		if featureEntities == nil then
			featureEntities = {}
			self._entitiesByFeature[featureName] = featureEntities
		end
		featureEntities[entity] = true

		return Result.Ok(featureName)
	end, "EntityRuntimeParticipationService:RegisterRuntimeEntity")
end

function EntityRuntimeParticipationService:UnregisterRuntimeEntity(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		local featureName = self._featureByEntity[entity]
		if featureName == nil then
			return Result.Ok(false)
		end

		self._featureByEntity[entity] = nil
		local featureEntities = self._entitiesByFeature[featureName]
		if featureEntities ~= nil then
			featureEntities[entity] = nil
			if next(featureEntities) == nil then
				self._entitiesByFeature[featureName] = nil
			end
		end

		return Result.Ok(true)
	end, "EntityRuntimeParticipationService:UnregisterRuntimeEntity")
end

function EntityRuntimeParticipationService:IsRuntimeEntity(entity: number): boolean
	return self._featureByEntity[entity] ~= nil
end

function EntityRuntimeParticipationService:GetFeatureName(entity: number): string?
	return self._featureByEntity[entity]
end

function EntityRuntimeParticipationService:CollectRuntimeEntitiesForFeature(featureName: string): { number }
	local featureEntities = self._entitiesByFeature[featureName]
	if featureEntities == nil then
		return {}
	end

	local entities = {}
	for entity in pairs(featureEntities) do
		table.insert(entities, entity)
	end
	table.sort(entities)
	return entities
end

function EntityRuntimeParticipationService:GetEnabledFeatures(mode: TRuntimeMode): { string }
	local enabledFeatures = self._enabledFeaturesByMode[mode]
	if enabledFeatures == nil then
		return {}
	end

	return _CollectSortedKeys(enabledFeatures)
end

function EntityRuntimeParticipationService:CollectRuntimeEntities(): { number }
	local entities = {}
	for entity in pairs(self._featureByEntity) do
		table.insert(entities, entity)
	end
	table.sort(entities)
	return entities
end

function EntityRuntimeParticipationService:GetStatus(): any
	local runtimeEntityCount = 0
	for _ in pairs(self._featureByEntity) do
		runtimeEntityCount += 1
	end

	return table.freeze({
		EnabledFeatures = table.freeze({
			Binding = table.freeze(self:GetEnabledFeatures("Binding")),
			Sync = table.freeze(self:GetEnabledFeatures("Sync")),
			Replication = table.freeze(self:GetEnabledFeatures("Replication")),
		}),
		RuntimeEntityCount = runtimeEntityCount,
	})
end

return EntityRuntimeParticipationService
