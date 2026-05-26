--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetSyncContributorQuery = {}
GetSyncContributorQuery.__index = GetSyncContributorQuery
setmetatable(GetSyncContributorQuery, BaseQuery)

function GetSyncContributorQuery.new()
	local self = BaseQuery.new("Entity", "GetSyncContributor")
	return setmetatable(self, GetSyncContributorQuery)
end
function GetSyncContributorQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
	})
end

function GetSyncContributorQuery:Execute(featureName: string): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetSyncContributor", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Result.Ok(self._syncContributorRegistry:GetSyncContributor(featureName))
	end, self:_Label())
end

return GetSyncContributorQuery