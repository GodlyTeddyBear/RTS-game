--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RunAcceptanceCheckQuery = {}
RunAcceptanceCheckQuery.__index = RunAcceptanceCheckQuery
setmetatable(RunAcceptanceCheckQuery, BaseQuery)

function RunAcceptanceCheckQuery.new()
	local self = BaseQuery.new("Entity", "RunAcceptanceCheck")
	return setmetatable(self, RunAcceptanceCheckQuery)
end

function RunAcceptanceCheckQuery:Init(registry: any, _name: string)
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

function RunAcceptanceCheckQuery:Execute(): Result.Result<any>
	return Result.Catch(function()
		local readinessStatus = EntityOperationSupport.BuildReadinessStatus(self)
		local acceptanceReport = table.clone(readinessStatus.Acceptance)
		acceptanceReport.LifecycleState = readinessStatus.LifecycleState
		return Result.Ok(acceptanceReport)
	end, self:_Label())
end

return RunAcceptanceCheckQuery
