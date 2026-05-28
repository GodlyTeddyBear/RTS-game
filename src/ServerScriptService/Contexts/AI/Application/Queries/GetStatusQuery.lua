--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)

local BasicActions = require(script.Parent.Parent.Parent.Config.Actions.BasicActions)
local BasicBehaviors = require(script.Parent.Parent.Parent.Config.Behaviors.BasicBehaviors)
local BasicEvaluations = require(script.Parent.Parent.Parent.Config.Evaluations.BasicEvaluations)
local BasicFactProviders = require(script.Parent.Parent.Parent.Config.Facts.BasicFactProviders)
local BasicAIProfiles = require(script.Parent.Parent.Parent.Config.Profiles.BasicAIProfiles)

local GetStatusQuery = {}
GetStatusQuery.__index = GetStatusQuery
setmetatable(GetStatusQuery, BaseQuery)

function GetStatusQuery.new()
	local self = BaseQuery.new("AI", "GetStatus")
	return setmetatable(self, GetStatusQuery)
end

function GetStatusQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_behaviorRegistry = "AIBehaviorDefinitionRegistry",
		_evaluationRegistry = "AIEvaluationRegistry",
		_actionRegistry = "AIActionDefinitionRegistry",
		_factProviderRegistry = "AIFactProviderRegistry",
		_profileRegistry = "AIEntityProfileRegistry",
	})
end

function GetStatusQuery:Execute(
	schemaRegistered: boolean,
	systemsRegistered: boolean,
	cleanupRegistered: boolean,
	builtInsSeeded: boolean
): Result.Result<any>
	return Result.Catch(function()
		return Result.Ok(table.freeze({
			SchemaRegistered = schemaRegistered,
			SystemsRegistered = systemsRegistered,
			CleanupRegistered = cleanupRegistered,
			BuiltInsSeeded = builtInsSeeded,
			BehaviorDefinitions = self._behaviorRegistry:GetStatus(),
			Evaluations = self._evaluationRegistry:GetStatus(),
			ActionDefinitions = self._actionRegistry:GetStatus(),
			FactProviders = self._factProviderRegistry:GetStatus(),
			Profiles = self._profileRegistry:GetStatus(),
			BuiltInCatalogs = table.freeze({
				EvaluationCount = self:_CountEntries(BasicEvaluations),
				ActionCount = self:_CountEntries(BasicActions),
				FactProviderCount = self:_CountEntries(BasicFactProviders),
				BehaviorDefinitionCount = self:_CountEntries(BasicBehaviors),
				ProfileCount = self:_CountEntries(BasicAIProfiles),
			}),
		}))
	end, self:_Label())
end

function GetStatusQuery:_CountEntries(map: any): number
	local count = 0
	for _ in pairs(map) do
		count += 1
	end
	return count
end

return GetStatusQuery
