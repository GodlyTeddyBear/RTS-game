--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

type TAIEntityProfile = AISharedContract.TAIEntityProfile

local SetupEntityAICommand = {}
SetupEntityAICommand.__index = SetupEntityAICommand
setmetatable(SetupEntityAICommand, BaseCommand)

function SetupEntityAICommand.new()
	local self = BaseCommand.new("AI", "SetupEntityAI")
	return setmetatable(self, SetupEntityAICommand)
end

function SetupEntityAICommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_setupPolicy", "AIEntitySetupPolicy")
end

function SetupEntityAICommand:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "SetupEntityAICommand missing EntityContext in Start")
end

function SetupEntityAICommand:Execute(entity: number, profile: TAIEntityProfile): Result.Result<boolean>
	return Result.Catch(function()
		local existsResult = self:_EntityExists(entity)
		if not existsResult.success then
			return existsResult
		end

		local setupResult = self._setupPolicy:Check(profile)
		if not setupResult.success then
			return setupResult
		end

		return self:_WriteSetupComponents(entity, setupResult.value.Profile)
	end, self:_Label())
end
function SetupEntityAICommand:_EntityExists(entity: number): Result.Result<boolean>
	if type(entity) ~= "number" then
		return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
			Entity = entity,
		})
	end

	local hasResult = self._entityContext:Has(entity, "Identity", "Entity")
	if not hasResult.success then
		return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
			Entity = entity,
			CauseType = hasResult.type,
			CauseMessage = hasResult.message,
			Details = hasResult.data,
		})
	end

	if hasResult.value ~= true then
		return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
			Entity = entity,
		})
	end

	return Result.Ok(true)
end

function SetupEntityAICommand:_WriteSetupComponents(
	entity: number,
	profile: TAIEntityProfile
): Result.Result<boolean>
	local timestamp = os.clock()
	local writes = {
		{
			Key = AISharedContract.Components.BehaviorTree,
			Value = AISharedContract.BuildBehaviorTree(profile),
		},
		{
			Key = AISharedContract.Components.CurrentBehavior,
			Value = AISharedContract.BuildCurrentBehavior(profile, timestamp),
		},
		{
			Key = AISharedContract.Components.DesiredBehavior,
			Value = AISharedContract.BuildDesiredBehavior(profile),
		},
		{
			Key = AISharedContract.Components.BehaviorState,
			Value = AISharedContract.BuildBehaviorState(profile),
		},
		{
			Key = AISharedContract.Components.ActionState,
			Value = AISharedContract.BuildActionState(profile),
		},
	}

	for _, write in ipairs(writes) do
		local writeResult = self._entityContext:Set(entity, write.Key, write.Value, AISharedContract.FeatureName)
		if not writeResult.success then
			return writeResult
		end
	end

	return Result.Ok(true)
end

return SetupEntityAICommand
