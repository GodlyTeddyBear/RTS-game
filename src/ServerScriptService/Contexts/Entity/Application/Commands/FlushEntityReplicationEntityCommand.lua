--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local FlushEntityReplicationEntityCommand = {}
FlushEntityReplicationEntityCommand.__index = FlushEntityReplicationEntityCommand
setmetatable(FlushEntityReplicationEntityCommand, BaseCommand)

function FlushEntityReplicationEntityCommand.new()
	local self = BaseCommand.new("Entity", "FlushEntityReplicationEntity")
	return setmetatable(self, FlushEntityReplicationEntityCommand)
end
function FlushEntityReplicationEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_replicationService = "EntityReplicationService",
		_validationService = "EntityValidationService",
	})
end

function FlushEntityReplicationEntityCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "FlushEntityReplicationEntity", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushEntityResult(entity)
	end, self:_Label())
end

return FlushEntityReplicationEntityCommand