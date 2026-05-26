--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local BindEntityInstanceCommand = {}
BindEntityInstanceCommand.__index = BindEntityInstanceCommand
setmetatable(BindEntityInstanceCommand, BaseCommand)

function BindEntityInstanceCommand.new()
	local self = BaseCommand.new("Entity", "BindEntityInstance")
	return setmetatable(self, BindEntityInstanceCommand)
end
function BindEntityInstanceCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_validationService = "EntityValidationService",
		_lifecycle = "EntityLifecycleStateMachine",
		_entityContext = "EntityContextService",
		_replicationService = "EntityReplicationService",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function BindEntityInstanceCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "BindEntityInstance", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local participationResult = EntityOperationSupport.RequireRuntimeBindingParticipation(self._runtimeParticipation, entity)
		if not participationResult.success then
			return participationResult
		end

		local bindResult = self._instanceBindingService:BindEntityInstance(self._entityContext, entity)
		if bindResult.success and bindResult.value ~= nil then
			local runtimeResult = EntityOperationSupport.OnRuntimeEntityBound(self._entityContext, self._runtimeParticipation, self._replicationService, entity)
			if not runtimeResult.success then
				return runtimeResult
			end
		end

		return bindResult
	end, self:_Label())
end

return BindEntityInstanceCommand