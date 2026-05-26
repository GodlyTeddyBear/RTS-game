--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local FlushEntityReplicationUnreliableCommand = {}
FlushEntityReplicationUnreliableCommand.__index = FlushEntityReplicationUnreliableCommand
setmetatable(FlushEntityReplicationUnreliableCommand, BaseCommand)

function FlushEntityReplicationUnreliableCommand.new()
	local self = BaseCommand.new("Entity", "FlushEntityReplicationUnreliable")
	return setmetatable(self, FlushEntityReplicationUnreliableCommand)
end
function FlushEntityReplicationUnreliableCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_replicationService = "EntityReplicationService",
		_validationService = "EntityValidationService",
	})
end

function FlushEntityReplicationUnreliableCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "FlushEntityReplicationUnreliable", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushUnreliableResult()
	end, self:_Label())
end

return FlushEntityReplicationUnreliableCommand