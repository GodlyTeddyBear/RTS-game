--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local FlushEntityReplicationReliableCommand = {}
FlushEntityReplicationReliableCommand.__index = FlushEntityReplicationReliableCommand
setmetatable(FlushEntityReplicationReliableCommand, BaseCommand)

function FlushEntityReplicationReliableCommand.new()
	local self = BaseCommand.new("Entity", "FlushEntityReplicationReliable")
	return setmetatable(self, FlushEntityReplicationReliableCommand)
end
function FlushEntityReplicationReliableCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_replicationService = "EntityReplicationService",
		_validationService = "EntityValidationService",
	})
end

function FlushEntityReplicationReliableCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "FlushEntityReplicationReliable", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushReliableResult()
	end, self:_Label())
end

return FlushEntityReplicationReliableCommand