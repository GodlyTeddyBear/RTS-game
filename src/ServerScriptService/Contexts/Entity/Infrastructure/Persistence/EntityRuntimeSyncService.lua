--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityRuntimeSyncService = {}
EntityRuntimeSyncService.__index = EntityRuntimeSyncService

function EntityRuntimeSyncService.new()
	local self = setmetatable({}, EntityRuntimeSyncService)
	self._runtimeParticipation = nil
	self._bindingService = nil
	self._syncContributorRegistry = nil
	return self
end

function EntityRuntimeSyncService:Init(registry: any, _name: string)
	self._runtimeParticipation = registry:Get("EntityRuntimeParticipationService")
	self._bindingService = registry:Get("EntityInstanceBindingService")
	self._syncContributorRegistry = registry:Get("EntitySyncContributorRegistry")
end

function EntityRuntimeSyncService:RunRuntimeSync(entityContext: any): Result.Result<number>
	return Result.Catch(function()
		local syncedCount = 0

		for _, featureName in ipairs(self._runtimeParticipation:GetEnabledFeatures("Sync")) do
			local contributor = self._syncContributorRegistry:GetSyncContributor(featureName)
			if contributor == nil then
				continue
			end

			if type(contributor.SyncAll) == "function" then
				pcall(contributor.SyncAll, entityContext)
			end

			for _, entity in ipairs(self:_ResolveEntitiesForSync(entityContext, featureName, contributor)) do
				local boundInstance = self._bindingService:GetBoundInstance(entity)
				if boundInstance == nil or not boundInstance:IsA("Model") or boundInstance.Parent == nil then
					continue
				end

				if type(contributor.SyncEntity) == "function" then
					local didSync = pcall(contributor.SyncEntity, entityContext, entity, boundInstance)
					if didSync then
						syncedCount += 1
					end
				end
			end
		end

		return Result.Ok(syncedCount)
	end, "EntityRuntimeSyncService:RunRuntimeSync")
end

function EntityRuntimeSyncService:RunRuntimePoll(entityContext: any): Result.Result<number>
	return Result.Catch(function()
		local polledCount = 0

		for _, featureName in ipairs(self._runtimeParticipation:GetEnabledFeatures("Sync")) do
			local contributor = self._syncContributorRegistry:GetSyncContributor(featureName)
			if contributor == nil then
				continue
			end

			for _, entity in ipairs(self:_ResolveEntitiesForPoll(entityContext, featureName, contributor)) do
				local boundInstance = self._bindingService:GetBoundInstance(entity)
				if boundInstance == nil or not boundInstance:IsA("Model") or boundInstance.Parent == nil then
					continue
				end

				if type(contributor.PollEntity) == "function" then
					local didPoll = pcall(contributor.PollEntity, entityContext, entity, boundInstance)
					if didPoll then
						polledCount += 1
					end
				end
			end
		end

		return Result.Ok(polledCount)
	end, "EntityRuntimeSyncService:RunRuntimePoll")
end

function EntityRuntimeSyncService:_ResolveEntitiesForSync(entityContext: any, featureName: string, contributor: any): { number }
	local querySyncEntities = contributor.QuerySyncEntities
	if type(querySyncEntities) == "function" then
		local didQuery, entities = pcall(querySyncEntities, entityContext)
		if didQuery and type(entities) == "table" then
			return self:_FilterRuntimeEntities(featureName, entities)
		end
	end

	return self._runtimeParticipation:CollectRuntimeEntitiesForFeature(featureName)
end

function EntityRuntimeSyncService:_ResolveEntitiesForPoll(entityContext: any, featureName: string, contributor: any): { number }
	local queryPollEntities = contributor.QueryPollEntities
	if type(queryPollEntities) == "function" then
		local didQuery, entities = pcall(queryPollEntities, entityContext)
		if didQuery and type(entities) == "table" then
			return self:_FilterRuntimeEntities(featureName, entities)
		end
	end

	return self._runtimeParticipation:CollectRuntimeEntitiesForFeature(featureName)
end

function EntityRuntimeSyncService:_FilterRuntimeEntities(featureName: string, entities: { number }): { number }
	local filtered = {}
	for _, entity in ipairs(entities) do
		if self._runtimeParticipation:GetFeatureName(entity) == featureName then
			table.insert(filtered, entity)
		end
	end
	table.sort(filtered)
	return filtered
end

return EntityRuntimeSyncService
