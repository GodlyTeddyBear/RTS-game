--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local CleanupEntityAICommand = {}
CleanupEntityAICommand.__index = CleanupEntityAICommand
setmetatable(CleanupEntityAICommand, BaseCommand)

local AI_KEYS = table.freeze({
	AISharedContract.Components.BehaviorTree,
	AISharedContract.Components.CurrentBehavior,
	AISharedContract.Components.DesiredBehavior,
	AISharedContract.Components.BehaviorState,
	AISharedContract.Components.ActionIntent,
	AISharedContract.Components.ActionState,
	AISharedContract.Tags.BehaviorDirtyTag,
	AISharedContract.Tags.ActionIntentTag,
	AISharedContract.Tags.ActionDirtyTag,
})

function CleanupEntityAICommand.new()
	local self = BaseCommand.new("AI", "CleanupEntityAI")
	return setmetatable(self, CleanupEntityAICommand)
end

function CleanupEntityAICommand:Init(registry: any, _name: string)
	self._registry = registry
	if registry ~= nil and type(registry) == "table" and type(registry.Modules) == "table" then
		self._entityContext = registry.Modules.EntityContext
	end
end

function CleanupEntityAICommand:Execute(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		self:_EnsureEntityContext()

		local existsResult = self:_EntityExists(entity)
		if not existsResult.success then
			return existsResult
		end
		if existsResult.value ~= true then
			return Result.Ok(false)
		end

		for _, key in ipairs(AI_KEYS) do
			local removeResult = self._entityContext:Remove(entity, key, AISharedContract.FeatureName)
			if not removeResult.success then
				return removeResult
			end
		end

		return Result.Ok(true)
	end, self:_Label())
end

function CleanupEntityAICommand:_EnsureEntityContext()
	if self._entityContext ~= nil then
		return
	end
	assert(self._registry ~= nil, "CleanupEntityAICommand missing registry for EntityContext resolution")
	self._entityContext = self._registry:Get("EntityContext")
end

function CleanupEntityAICommand:_EntityExists(entity: number): Result.Result<boolean>
	if type(entity) ~= "number" then
		return Result.Ok(false)
	end

	local hasResult = self._entityContext:Has(entity, "Identity", "Entity")
	if not hasResult.success then
		return hasResult
	end

	return Result.Ok(hasResult.value == true)
end

return CleanupEntityAICommand
