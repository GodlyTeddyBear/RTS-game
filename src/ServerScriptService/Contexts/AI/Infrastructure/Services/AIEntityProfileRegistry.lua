--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

type TAIEntityProfile = AISharedContract.TAIEntityProfile

export type TAIEntityProfileRecord = TAIEntityProfile & {
	ProfileId: string,
	Metadata: any?,
}

local AIEntityProfileRegistry = {}
AIEntityProfileRegistry.__index = AIEntityProfileRegistry

function AIEntityProfileRegistry.new()
	local self = setmetatable({}, AIEntityProfileRegistry)
	self._profilesById = {}
	return self
end

function AIEntityProfileRegistry:Init(registry: any, _name: string)
	self._setupPolicy = registry:Get("AIEntitySetupPolicy")
end

function AIEntityProfileRegistry:RegisterProfile(payload: TAIEntityProfileRecord): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		self._profilesById[payload.ProfileId] = table.freeze({
			ProfileId = payload.ProfileId,
			DefinitionId = payload.DefinitionId,
			TickInterval = payload.TickInterval,
			InitialBehaviorId = payload.InitialBehaviorId,
			InitialNodePath = self:_CloneAndFreeze(payload.InitialNodePath),
			Blackboard = self:_CloneAndFreeze(payload.Blackboard),
			ActionStateStatus = payload.ActionStateStatus,
			Metadata = self:_CloneAndFreeze(payload.Metadata),
		})

		return Result.Ok(true)
	end, "AIEntityProfileRegistry:RegisterProfile")
end

function AIEntityProfileRegistry:GetProfile(profileId: string): any?
	return self._profilesById[profileId]
end

function AIEntityProfileRegistry:GetStatus(): any
	return table.freeze({
		ProfileCount = self:_CountProfiles(),
	})
end

function AIEntityProfileRegistry:_ValidatePayload(payload: TAIEntityProfileRecord): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.ProfileId) ~= "string" or payload.ProfileId == "" then
		return Result.Err("InvalidProfile", Errors.INVALID_PROFILE, {
			Reason = "MissingProfileId",
		})
	end
	if self._profilesById[payload.ProfileId] ~= nil then
		return Result.Err("DuplicateProfile", Errors.DUPLICATE_PROFILE, {
			ProfileId = payload.ProfileId,
		})
	end
	if self._setupPolicy == nil then
		return Result.Err("InvalidProfile", Errors.INVALID_PROFILE, {
			ProfileId = payload.ProfileId,
			Reason = "RegistryNotInitialized",
		})
	end

	local setupResult = self._setupPolicy:Check(payload)
	if not setupResult.success then
		return Result.Err("InvalidProfile", Errors.INVALID_PROFILE, {
			ProfileId = payload.ProfileId,
			CauseType = setupResult.type,
			CauseMessage = setupResult.message,
			Details = setupResult.data,
		})
	end

	return Result.Ok(true)
end

function AIEntityProfileRegistry:_CloneAndFreeze(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_CloneAndFreeze(nestedValue)
	end

	return table.freeze(clone)
end

function AIEntityProfileRegistry:_CountProfiles(): number
	local count = 0
	for _ in pairs(self._profilesById) do
		count += 1
	end
	return count
end

return AIEntityProfileRegistry
