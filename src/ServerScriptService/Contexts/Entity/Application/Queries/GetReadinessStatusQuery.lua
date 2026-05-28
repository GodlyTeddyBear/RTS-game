--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetReadinessStatusQuery = {}
GetReadinessStatusQuery.__index = GetReadinessStatusQuery
setmetatable(GetReadinessStatusQuery, BaseQuery)

function GetReadinessStatusQuery.new()
	local self = BaseQuery.new("Entity", "GetReadinessStatus")
	return setmetatable(self, GetReadinessStatusQuery)
end

function GetReadinessStatusQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_readinessPolicy = "EntityReadinessPolicy",
		_startupState = "EntityStartupStateService",
		_runtimeScheduler = "EntityRuntimeSchedulerService",
		_schemaRegistry = "EntitySchemaRegistry",
		_systemRegistry = "EntitySystemRegistry",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_replicationRegistry = "EntityReplicationRegistry",
		_replicationService = "EntityReplicationService",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function GetReadinessStatusQuery:Execute(): Result.Result<any>
	return Result.Catch(function()
		return Result.Ok(EntityOperationSupport.BuildReadinessStatus(self))
	end, self:_Label())
end

return GetReadinessStatusQuery
