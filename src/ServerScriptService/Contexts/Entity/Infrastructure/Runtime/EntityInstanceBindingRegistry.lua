--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local function _ValidateCallback(binding: any, key: string, isRequired: boolean): Result.Result<boolean>
	local value = binding[key]
	if value == nil and not isRequired then
		return Result.Ok(true)
	end

	if type(value) ~= "function" then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			Key = key,
			IsRequired = isRequired,
		})
	end

	return Result.Ok(true)
end

local EntityInstanceBindingRegistry = {}
EntityInstanceBindingRegistry.__index = EntityInstanceBindingRegistry

function EntityInstanceBindingRegistry.new()
	local self = setmetatable({}, EntityInstanceBindingRegistry)
	self._bindingsByFeature = {}
	self._isRegistrationClosed = false
	return self
end

function EntityInstanceBindingRegistry:Init(_registry: any, _name: string)
	return
end

function EntityInstanceBindingRegistry:RegisterBinding(featureName: string, binding: any): Result.Result<any>
	return Result.Catch(function()
		if self._isRegistrationClosed then
			return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
				FeatureName = featureName,
				Reason = "RegistrationClosed",
			})
		end

		if type(featureName) ~= "string" or featureName == "" or type(binding) ~= "table" then
			return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
				FeatureName = featureName,
			})
		end

		if self._bindingsByFeature[featureName] ~= nil then
			return Result.Err("DuplicateInstanceBinding", Errors.DUPLICATE_INSTANCE_BINDING, {
				FeatureName = featureName,
			})
		end

		if binding.FeatureName ~= featureName then
			return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
				FeatureName = featureName,
				Reason = "FeatureNameMismatch",
			})
		end

		local requiredResolveAsset = _ValidateCallback(binding, "ResolveAsset", true)
		if not requiredResolveAsset.success then
			return requiredResolveAsset
		end

		local optionalKeys = {
			"BuildActorKind",
			"ResolveParentFolder",
			"PrepareInstance",
			"BuildRevealAttributes",
			"BuildRevealTags",
			"BuildRevealClearAttributes",
			"BuildName",
		}

		for _, key in ipairs(optionalKeys) do
			local callbackResult = _ValidateCallback(binding, key, false)
			if not callbackResult.success then
				return callbackResult
			end
		end

		local compiledBinding = table.freeze({
			FeatureName = featureName,
			BuildActorKind = binding.BuildActorKind,
			ResolveAsset = binding.ResolveAsset,
			ResolveParentFolder = binding.ResolveParentFolder,
			PrepareInstance = binding.PrepareInstance,
			BuildRevealAttributes = binding.BuildRevealAttributes,
			BuildRevealTags = binding.BuildRevealTags,
			BuildRevealClearAttributes = binding.BuildRevealClearAttributes,
			BuildName = binding.BuildName,
		})

		self._bindingsByFeature[featureName] = compiledBinding
		return Result.Ok(compiledBinding)
	end, "EntityInstanceBindingRegistry:RegisterBinding")
end

function EntityInstanceBindingRegistry:GetBinding(featureName: string)
	return self._bindingsByFeature[featureName]
end

function EntityInstanceBindingRegistry:CloseRegistration(): Result.Result<boolean>
	return Result.Catch(function()
		self._isRegistrationClosed = true
		return Result.Ok(true)
	end, "EntityInstanceBindingRegistry:CloseRegistration")
end

function EntityInstanceBindingRegistry:ValidateReady(): Result.Result<boolean>
	if not self._isRegistrationClosed then
		return Result.Err("InvalidInstanceBinding", Errors.INVALID_INSTANCE_BINDING, {
			Reason = "RegistrationStillOpen",
		})
	end

	return Result.Ok(true)
end

function EntityInstanceBindingRegistry:GetStatus(): any
	local bindingCount = 0
	for _ in pairs(self._bindingsByFeature) do
		bindingCount += 1
	end

	return table.freeze({
		RegistrationClosed = self._isRegistrationClosed,
		BindingCount = bindingCount,
	})
end

return EntityInstanceBindingRegistry
