--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AIActionIntentValidationSystem = require(script.Parent.Parent.Parent.Infrastructure.ECS.AIActionIntentValidationSystem)
local AIActionLifecycleSystem = require(script.Parent.Parent.Parent.Infrastructure.ECS.AIActionLifecycleSystem)
local AIBehaviorCommitSystem = require(script.Parent.Parent.Parent.Infrastructure.ECS.AIBehaviorCommitSystem)
local AIBehaviorSelectionSystem = require(script.Parent.Parent.Parent.Infrastructure.ECS.AIBehaviorSelectionSystem)
local Errors = require(script.Parent.Parent.Parent.Errors)

local RegisterAIEntitySystemsCommand = {}
RegisterAIEntitySystemsCommand.__index = RegisterAIEntitySystemsCommand
setmetatable(RegisterAIEntitySystemsCommand, BaseCommand)

function RegisterAIEntitySystemsCommand.new()
	local self = BaseCommand.new("AI", "RegisterAIEntitySystems")
	return setmetatable(self, RegisterAIEntitySystemsCommand)
end

function RegisterAIEntitySystemsCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContext",
		_factProviderRegistry = "AIFactProviderRegistry",
		_decisionEvaluator = "AIEntityDecisionEvaluator",
	})
end

function RegisterAIEntitySystemsCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local selectionResult = self:_RegisterBehaviorSelectionSystem()
		if not selectionResult.success then
			return selectionResult
		end

		local behaviorResult = self:_RegisterBehaviorCommitSystem()
		if not behaviorResult.success then
			return behaviorResult
		end

		local actionResult = self:_RegisterActionIntentValidationSystem()
		if not actionResult.success then
			return actionResult
		end

		local lifecycleResult = self:_RegisterActionLifecycleSystem()
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Result.Ok(true)
	end, self:_Label())
end

function RegisterAIEntitySystemsCommand:_RegisterBehaviorSelectionSystem(): Result.Result<boolean>
	return self:_RegisterSystem("Decide", {
		Name = "AIBehaviorSelectionSystem",
		Phase = "Decide",
		Reads = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.BehaviorTree,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.CurrentBehavior,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.BehaviorState,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.ActionState,
		},
		Writes = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.DesiredBehavior,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.ActionIntent,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionIntentTag,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionDirtyTag,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.BehaviorDirtyTag,
		},
		Factory = function(entityFactory: any, _compiledSchemas: any)
			return AIBehaviorSelectionSystem.new(
				entityFactory,
				self._entityContext,
				self._factProviderRegistry,
				self._decisionEvaluator
			)
		end,
	})
end

function RegisterAIEntitySystemsCommand:_RegisterBehaviorCommitSystem(): Result.Result<boolean>
	return self:_RegisterSystem("Commit", {
		Name = "AIBehaviorCommitSystem",
		Phase = "Commit",
		Reads = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.DesiredBehavior,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.BehaviorState,
		},
		Writes = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.CurrentBehavior,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.BehaviorState,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.BehaviorDirtyTag,
		},
		Factory = function(entityFactory: any, _compiledSchemas: any)
			return AIBehaviorCommitSystem.new(entityFactory)
		end,
	})
end

function RegisterAIEntitySystemsCommand:_RegisterActionIntentValidationSystem(): Result.Result<boolean>
	return self:_RegisterSystem("Commit", {
		Name = "AIActionIntentValidationSystem",
		Phase = "Commit",
		Reads = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.ActionIntent,
		},
		Writes = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionIntentTag,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionDirtyTag,
		},
		Factory = function(entityFactory: any, _compiledSchemas: any)
			return AIActionIntentValidationSystem.new(entityFactory)
		end,
	})
end

function RegisterAIEntitySystemsCommand:_RegisterActionLifecycleSystem(): Result.Result<boolean>
	return self:_RegisterSystem("Execute", {
		Name = "AIActionLifecycleSystem",
		Phase = "Execute",
		Reads = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.ActionIntent,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionIntentTag,
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.ActionState,
		},
		Writes = {
			AISharedContract.FeatureName .. "." .. AISharedContract.Components.ActionState,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionIntentTag,
			AISharedContract.FeatureName .. "." .. AISharedContract.Tags.ActionDirtyTag,
		},
		Factory = function(entityFactory: any, _compiledSchemas: any)
			return AIActionLifecycleSystem.new(entityFactory)
		end,
	})
end

function RegisterAIEntitySystemsCommand:_RegisterSystem(phaseName: string, systemSpec: any): Result.Result<boolean>
	local registerResult = self._entityContext:RegisterSystem(phaseName, systemSpec)
	if registerResult.success then
		return Result.Ok(true)
	end

	return Result.Err("AIEntitySystemRegistrationFailed", Errors.AI_ENTITY_SYSTEM_REGISTRATION_FAILED, {
		PhaseName = phaseName,
		SystemName = systemSpec.Name,
		CauseType = registerResult.type,
		CauseMessage = registerResult.message,
		Details = registerResult.data,
	})
end

return RegisterAIEntitySystemsCommand
