--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local OPTIONAL_CALLBACKS = {
	"RegisterEntity",
	"UnregisterEntity",
	"BuildSchema",
}

local EntityReplicationRegistry = {}
EntityReplicationRegistry.__index = EntityReplicationRegistry

function EntityReplicationRegistry.new()
	local self = setmetatable({}, EntityReplicationRegistry)
	self._surfacesByFeature = {}
	self._isRegistrationClosed = false
	return self
end

function EntityReplicationRegistry:Init(_registry: any, _name: string)
	return
end

function EntityReplicationRegistry:RegisterReplicationSurface(featureName: string, payload: any): Result.Result<any>
	return Result.Catch(function()
		if self._isRegistrationClosed then
			return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
				FeatureName = featureName,
				Reason = "RegistrationClosed",
			})
		end

		if type(featureName) ~= "string" or featureName == "" or type(payload) ~= "table" then
			return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
				FeatureName = featureName,
			})
		end

		if featureName == "Base" then
			return Result.Err("UnsupportedReplicationFeature", Errors.UNSUPPORTED_REPLICATION_FEATURE, {
				FeatureName = featureName,
			})
		end

		if payload.FeatureName ~= featureName then
			return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
				FeatureName = featureName,
				Reason = "FeatureNameMismatch",
			})
		end

		if self._surfacesByFeature[featureName] ~= nil then
			return Result.Err("DuplicateReplicationSurface", Errors.DUPLICATE_REPLICATION_SURFACE, {
				FeatureName = featureName,
			})
		end

		for _, key in ipairs(OPTIONAL_CALLBACKS) do
			local callback = payload[key]
			if callback ~= nil and type(callback) ~= "function" then
				return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
					FeatureName = featureName,
					Key = key,
				})
			end
		end

		local compiledSurface = table.freeze({
			FeatureName = featureName,
			SharedComponents = type(payload.SharedComponents) == "table" and table.clone(payload.SharedComponents) or nil,
			SharedTags = type(payload.SharedTags) == "table" and table.clone(payload.SharedTags) or nil,
			RegisterEntity = payload.RegisterEntity,
			UnregisterEntity = payload.UnregisterEntity,
			BuildSchema = payload.BuildSchema,
		})

		self._surfacesByFeature[featureName] = compiledSurface
		return Result.Ok(compiledSurface)
	end, "EntityReplicationRegistry:RegisterReplicationSurface")
end

function EntityReplicationRegistry:GetReplicationSurface(featureName: string)
	return self._surfacesByFeature[featureName]
end

function EntityReplicationRegistry:GetReplicationSurfaces()
	return self._surfacesByFeature
end

function EntityReplicationRegistry:CloseRegistration(): Result.Result<boolean>
	return Result.Catch(function()
		self._isRegistrationClosed = true
		return Result.Ok(true)
	end, "EntityReplicationRegistry:CloseRegistration")
end

function EntityReplicationRegistry:ValidateReady(): Result.Result<boolean>
	if not self._isRegistrationClosed then
		return Result.Err("InvalidReplicationSurface", Errors.INVALID_REPLICATION_SURFACE, {
			Reason = "RegistrationStillOpen",
		})
	end

	return Result.Ok(true)
end

function EntityReplicationRegistry:GetStatus(): any
	local surfaceCount = 0
	for _ in pairs(self._surfacesByFeature) do
		surfaceCount += 1
	end

	return table.freeze({
		RegistrationClosed = self._isRegistrationClosed,
		SurfaceCount = surfaceCount,
	})
end

return EntityReplicationRegistry
