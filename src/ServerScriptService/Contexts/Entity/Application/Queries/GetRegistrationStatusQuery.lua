--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetRegistrationStatusQuery = {}
GetRegistrationStatusQuery.__index = GetRegistrationStatusQuery
setmetatable(GetRegistrationStatusQuery, BaseQuery)

function GetRegistrationStatusQuery.new()
	local self = BaseQuery.new("Entity", "GetRegistrationStatus")
	return setmetatable(self, GetRegistrationStatusQuery)
end

function GetRegistrationStatusQuery:Init(registry: any, _name: string)
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

function GetRegistrationStatusQuery:Execute(): Result.Result<any>
	return Result.Catch(function()
		return Result.Ok(EntityOperationSupport.BuildReadinessStatus(self))
	end, self:_Label())
end

return GetRegistrationStatusQuery
