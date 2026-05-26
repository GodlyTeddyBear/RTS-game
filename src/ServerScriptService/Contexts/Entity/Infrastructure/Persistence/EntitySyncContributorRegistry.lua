--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local EntitySyncContributorRegistry = {}
EntitySyncContributorRegistry.__index = EntitySyncContributorRegistry

function EntitySyncContributorRegistry.new()
	local self = setmetatable({}, EntitySyncContributorRegistry)
	self._contributorsByFeature = {}
	self._isRegistrationClosed = false
	return self
end

function EntitySyncContributorRegistry:Init(_registry: any, _name: string)
	return
end

function EntitySyncContributorRegistry:RegisterSyncContributor(featureName: string, payload: any): Result.Result<any>
	return Result.Catch(function()
		if self._isRegistrationClosed then
			return Result.Err("InvalidSyncContributor", Errors.INVALID_SYNC_CONTRIBUTOR, {
				FeatureName = featureName,
				Reason = "RegistrationClosed",
			})
		end

		if type(featureName) ~= "string" or featureName == "" or type(payload) ~= "table" then
			return Result.Err("InvalidSyncContributor", Errors.INVALID_SYNC_CONTRIBUTOR, {
				FeatureName = featureName,
			})
		end

		if payload.FeatureName ~= featureName then
			return Result.Err("InvalidSyncContributor", Errors.INVALID_SYNC_CONTRIBUTOR, {
				FeatureName = featureName,
				Reason = "FeatureNameMismatch",
			})
		end

		if self._contributorsByFeature[featureName] ~= nil then
			return Result.Err("DuplicateSyncContributor", Errors.DUPLICATE_SYNC_CONTRIBUTOR, {
				FeatureName = featureName,
			})
		end

		local compiledContributor = table.freeze({
			FeatureName = featureName,
			SyncAll = payload.SyncAll,
			SyncEntity = payload.SyncEntity,
			PollEntity = payload.PollEntity,
			QuerySyncEntities = payload.QuerySyncEntities,
			QueryPollEntities = payload.QueryPollEntities,
		})

		self._contributorsByFeature[featureName] = compiledContributor
		return Result.Ok(compiledContributor)
	end, "EntitySyncContributorRegistry:RegisterSyncContributor")
end

function EntitySyncContributorRegistry:GetSyncContributor(featureName: string)
	return self._contributorsByFeature[featureName]
end

function EntitySyncContributorRegistry:CloseRegistration(): Result.Result<boolean>
	return Result.Catch(function()
		self._isRegistrationClosed = true
		return Result.Ok(true)
	end, "EntitySyncContributorRegistry:CloseRegistration")
end

function EntitySyncContributorRegistry:ValidateReady(): Result.Result<boolean>
	if not self._isRegistrationClosed then
		return Result.Err("InvalidSyncContributor", Errors.INVALID_SYNC_CONTRIBUTOR, {
			Reason = "RegistrationStillOpen",
		})
	end

	return Result.Ok(true)
end

function EntitySyncContributorRegistry:GetStatus(): any
	local contributorCount = 0
	for _ in pairs(self._contributorsByFeature) do
		contributorCount += 1
	end

	return table.freeze({
		RegistrationClosed = self._isRegistrationClosed,
		ContributorCount = contributorCount,
	})
end

return EntitySyncContributorRegistry
