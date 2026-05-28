--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local PROFILE_FIELDS = table.freeze({
	DefinitionId = true,
	TickInterval = true,
	InitialBehaviorId = true,
	InitialNodePath = true,
	Blackboard = true,
	ActionStateStatus = true,
})

local SetupEntityAIFromProfileCommand = {}
SetupEntityAIFromProfileCommand.__index = SetupEntityAIFromProfileCommand
setmetatable(SetupEntityAIFromProfileCommand, BaseCommand)

function SetupEntityAIFromProfileCommand.new()
	local self = BaseCommand.new("AI", "SetupEntityAIFromProfile")
	return setmetatable(self, SetupEntityAIFromProfileCommand)
end

function SetupEntityAIFromProfileCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_profileRegistry = "AIEntityProfileRegistry",
		_setupEntityAICommand = "SetupEntityAICommand",
	})
end

function SetupEntityAIFromProfileCommand:Execute(
	entity: number,
	profileId: string,
	overrides: any?
): Result.Result<boolean>
	return Result.Catch(function()
		if type(profileId) ~= "string" or profileId == "" then
			return Result.Err("UnknownAIProfile", Errors.UNKNOWN_AI_PROFILE, {
				ProfileId = profileId,
			})
		end

		local profile = self._profileRegistry:GetProfile(profileId)
		if profile == nil then
			return Result.Err("UnknownAIProfile", Errors.UNKNOWN_AI_PROFILE, {
				ProfileId = profileId,
			})
		end

		local profileResult = self:_BuildProfile(profile, overrides)
		if not profileResult.success then
			return profileResult
		end

		return self._setupEntityAICommand:Execute(entity, profileResult.value)
	end, self:_Label())
end

function SetupEntityAIFromProfileCommand:_BuildProfile(profile: any, overrides: any?): Result.Result<any>
	local resolvedProfile = {
		DefinitionId = profile.DefinitionId,
		TickInterval = profile.TickInterval,
		InitialBehaviorId = profile.InitialBehaviorId,
		InitialNodePath = self:_DeepClone(profile.InitialNodePath),
		Blackboard = self:_DeepClone(profile.Blackboard),
		ActionStateStatus = profile.ActionStateStatus,
	}

	if overrides == nil then
		return Result.Ok(resolvedProfile)
	end
	if type(overrides) ~= "table" then
		return Result.Err("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, {
			Reason = "OverridesMustBeTable",
		})
	end

	for key, value in pairs(overrides) do
		if PROFILE_FIELDS[key] ~= true then
			return Result.Err("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, {
				Reason = "UnsupportedProfileOverrideField",
				Field = key,
			})
		end
		resolvedProfile[key] = self:_DeepClone(value)
	end

	return Result.Ok(resolvedProfile)
end

function SetupEntityAIFromProfileCommand:_DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_DeepClone(nestedValue)
	end
	return clone
end

return SetupEntityAIFromProfileCommand
