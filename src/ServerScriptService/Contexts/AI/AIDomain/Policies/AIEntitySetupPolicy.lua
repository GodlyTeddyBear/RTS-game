--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Result = require(ReplicatedStorage.Utilities.Result)

local AIEntityProfileSpecs = require(script.Parent.Parent.Specs.AIEntityProfileSpecs)

type TAIEntityProfile = AISharedContract.TAIEntityProfile

local AIEntitySetupPolicy = {}
AIEntitySetupPolicy.__index = AIEntitySetupPolicy

function AIEntitySetupPolicy.new()
	return setmetatable({}, AIEntitySetupPolicy)
end

function AIEntitySetupPolicy:Init(registry: any, _name: string)
	self._behaviorRegistry = registry:Get("AIBehaviorDefinitionRegistry")
end

function AIEntitySetupPolicy:Check(profile: TAIEntityProfile): Result.Result<any>
	return Result.Catch(function()
		local candidate = self:_BuildCandidate(profile)
		local specResult = self:_EvaluateCandidate(candidate)
		if not specResult.success then
			return specResult
		end

		return Result.Ok({
			Profile = self:_NormalizeProfile(profile),
			Definition = self._behaviorRegistry:GetDefinition(profile.DefinitionId),
		})
	end, "AIEntitySetupPolicy:Check")
end

function AIEntitySetupPolicy:_EvaluateCandidate(candidate: AIEntityProfileSpecs.TAIEntityProfileCandidate): Result.Result<any>
	local orderedSpecs = {
		AIEntityProfileSpecs.HasProfileTable,
		AIEntityProfileSpecs.HasDefinitionId,
		AIEntityProfileSpecs.HasRegisteredDefinition,
		AIEntityProfileSpecs.HasValidTickInterval,
		AIEntityProfileSpecs.HasValidInitialBehaviorId,
		AIEntityProfileSpecs.HasValidNodePath,
		AIEntityProfileSpecs.HasValidActionStateStatus,
	}

	for _, spec in ipairs(orderedSpecs) do
		local result = spec:IsSatisfiedBy(candidate)
		if not result.success then
			return result
		end
	end

	return Result.Ok(candidate)
end

function AIEntitySetupPolicy:_BuildCandidate(profile: any): AIEntityProfileSpecs.TAIEntityProfileCandidate
	return {
		Profile = profile,
		DefinitionIdValid = type(profile) == "table" and type(profile.DefinitionId) == "string" and profile.DefinitionId ~= "",
		DefinitionRegistered = type(profile) == "table"
			and type(profile.DefinitionId) == "string"
			and self._behaviorRegistry:GetDefinition(profile.DefinitionId) ~= nil,
		TickIntervalValid = type(profile) == "table" and type(profile.TickInterval) == "number" and profile.TickInterval > 0,
		InitialBehaviorIdValid = type(profile) == "table"
			and (profile.InitialBehaviorId == nil or (type(profile.InitialBehaviorId) == "string" and profile.InitialBehaviorId ~= "")),
		NodePathValid = self:_IsValidNodePath(if type(profile) == "table" then profile.InitialNodePath else nil),
		ActionStateStatusValid = type(profile) == "table"
			and (
				profile.ActionStateStatus == nil
				or AISharedContract.IsActionStatus(profile.ActionStateStatus)
			),
	}
end

function AIEntitySetupPolicy:_NormalizeProfile(profile: TAIEntityProfile): TAIEntityProfile
	local nodePath = {}
	for _, nodeId in ipairs(profile.InitialNodePath or {}) do
		table.insert(nodePath, nodeId)
	end

	return {
		DefinitionId = profile.DefinitionId,
		TickInterval = profile.TickInterval,
		InitialBehaviorId = profile.InitialBehaviorId,
		InitialNodePath = nodePath,
		Blackboard = profile.Blackboard,
		ActionStateStatus = profile.ActionStateStatus,
	}
end

function AIEntitySetupPolicy:_IsValidNodePath(nodePath: any): boolean
	if nodePath == nil then
		return true
	end
	if type(nodePath) ~= "table" then
		return false
	end

	local count = 0
	for key, value in pairs(nodePath) do
		if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 or type(value) ~= "string" or value == "" then
			return false
		end
		count += 1
	end

	for index = 1, count do
		if type(nodePath[index]) ~= "string" then
			return false
		end
	end

	return true
end

return AIEntitySetupPolicy
