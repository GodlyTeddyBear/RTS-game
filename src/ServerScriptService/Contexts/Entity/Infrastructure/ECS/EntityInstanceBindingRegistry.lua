--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

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
