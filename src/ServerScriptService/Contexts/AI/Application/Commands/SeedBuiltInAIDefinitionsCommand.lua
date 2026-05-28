--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local BasicActions = require(script.Parent.Parent.Parent.Config.Actions.BasicActions)
local BasicBehaviors = require(script.Parent.Parent.Parent.Config.Behaviors.BasicBehaviors)
local BasicEvaluations = require(script.Parent.Parent.Parent.Config.Evaluations.BasicEvaluations)
local BasicFactProviders = require(script.Parent.Parent.Parent.Config.Facts.BasicFactProviders)
local BasicAIProfiles = require(script.Parent.Parent.Parent.Config.Profiles.BasicAIProfiles)
local Errors = require(script.Parent.Parent.Parent.Errors)

local SeedBuiltInAIDefinitionsCommand = {}
SeedBuiltInAIDefinitionsCommand.__index = SeedBuiltInAIDefinitionsCommand
setmetatable(SeedBuiltInAIDefinitionsCommand, BaseCommand)

function SeedBuiltInAIDefinitionsCommand.new()
	local self = BaseCommand.new("AI", "SeedBuiltInAIDefinitions")
	return setmetatable(self, SeedBuiltInAIDefinitionsCommand)
end

function SeedBuiltInAIDefinitionsCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_evaluationRegistry = "AIEvaluationRegistry",
		_actionRegistry = "AIActionDefinitionRegistry",
		_factProviderRegistry = "AIFactProviderRegistry",
		_behaviorRegistry = "AIBehaviorDefinitionRegistry",
		_profileRegistry = "AIEntityProfileRegistry",
	})
end

function SeedBuiltInAIDefinitionsCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local seedResult = self:_SeedEvaluations()
		if not seedResult.success then
			return seedResult
		end

		seedResult = self:_SeedActions()
		if not seedResult.success then
			return seedResult
		end

		seedResult = self:_SeedFactProviders()
		if not seedResult.success then
			return seedResult
		end

		seedResult = self:_SeedBehaviors()
		if not seedResult.success then
			return seedResult
		end

		return self:_SeedProfiles()
	end, self:_Label())
end

function SeedBuiltInAIDefinitionsCommand:_SeedEvaluations(): Result.Result<boolean>
	for evaluationId, payload in pairs(BasicEvaluations) do
		local idResult = self:_RequireCatalogId("Evaluation", evaluationId, payload, "EvaluationId")
		if not idResult.success then
			return idResult
		end

		if self._evaluationRegistry:GetEvaluation(payload.EvaluationId) == nil then
			local result = self._evaluationRegistry:RegisterEvaluation(payload)
			if not result.success then
				return self:_BuildSeedFailure("Evaluation", evaluationId, result)
			end
		end
	end

	return Result.Ok(true)
end

function SeedBuiltInAIDefinitionsCommand:_SeedActions(): Result.Result<boolean>
	for actionId, payload in pairs(BasicActions) do
		local idResult = self:_RequireCatalogId("Action", actionId, payload, "ActionId")
		if not idResult.success then
			return idResult
		end

		if self._actionRegistry:GetActionDefinition(payload.ActionId) == nil then
			local result = self._actionRegistry:RegisterActionDefinition(payload)
			if not result.success then
				return self:_BuildSeedFailure("Action", actionId, result)
			end
		end
	end

	return Result.Ok(true)
end

function SeedBuiltInAIDefinitionsCommand:_SeedFactProviders(): Result.Result<boolean>
	for providerId, payload in pairs(BasicFactProviders) do
		local idResult = self:_RequireCatalogId("FactProvider", providerId, payload, "ProviderId")
		if not idResult.success then
			return idResult
		end

		if self._factProviderRegistry:GetProvider(payload.ProviderId) == nil then
			local result = self._factProviderRegistry:RegisterFactProvider(payload)
			if not result.success then
				return self:_BuildSeedFailure("FactProvider", providerId, result)
			end
		end
	end

	return Result.Ok(true)
end

function SeedBuiltInAIDefinitionsCommand:_SeedBehaviors(): Result.Result<boolean>
	for definitionId, payload in pairs(BasicBehaviors) do
		local idResult = self:_RequireCatalogId("BehaviorDefinition", definitionId, payload, "DefinitionId")
		if not idResult.success then
			return idResult
		end

		if self._behaviorRegistry:GetDefinition(payload.DefinitionId) == nil then
			local result = self._behaviorRegistry:RegisterDefinition(payload)
			if not result.success then
				return self:_BuildSeedFailure("BehaviorDefinition", definitionId, result)
			end
		end
	end

	return Result.Ok(true)
end

function SeedBuiltInAIDefinitionsCommand:_SeedProfiles(): Result.Result<boolean>
	for profileId, payload in pairs(BasicAIProfiles) do
		local idResult = self:_RequireCatalogId("Profile", profileId, payload, "ProfileId")
		if not idResult.success then
			return idResult
		end

		if self._profileRegistry:GetProfile(payload.ProfileId) == nil then
			local result = self._profileRegistry:RegisterProfile(payload)
			if not result.success then
				return self:_BuildSeedFailure("Profile", profileId, result)
			end
		end
	end

	return Result.Ok(true)
end

function SeedBuiltInAIDefinitionsCommand:_RequireCatalogId(
	kind: string,
	catalogId: string,
	payload: any,
	idField: string
): Result.Result<boolean>
	if type(payload) ~= "table" or payload[idField] ~= catalogId then
		return Result.Err("AISeedFailed", Errors.AI_SEED_FAILED, {
			Kind = kind,
			Id = catalogId,
			Reason = "CatalogIdMismatch",
			IdField = idField,
			PayloadId = if type(payload) == "table" then payload[idField] else nil,
		})
	end

	return Result.Ok(true)
end

function SeedBuiltInAIDefinitionsCommand:_BuildSeedFailure(kind: string, id: string, result: any): Result.Result<boolean>
	return Result.Err("AISeedFailed", Errors.AI_SEED_FAILED, {
		Kind = kind,
		Id = id,
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	})
end

return SeedBuiltInAIDefinitionsCommand
