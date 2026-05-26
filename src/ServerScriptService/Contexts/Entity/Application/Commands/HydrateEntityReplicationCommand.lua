--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local HydrateEntityReplicationCommand = {}
HydrateEntityReplicationCommand.__index = HydrateEntityReplicationCommand
setmetatable(HydrateEntityReplicationCommand, BaseCommand)

function HydrateEntityReplicationCommand.new()
	local self = BaseCommand.new("Entity", "HydrateEntityReplication")
	return setmetatable(self, HydrateEntityReplicationCommand)
end
function HydrateEntityReplicationCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_replicationService = "EntityReplicationService",
		_validationService = "EntityValidationService",
	})
end

function HydrateEntityReplicationCommand:Execute(player: Player): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "HydrateEntityReplication", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:HydratePlayerResult(player)
	end, self:_Label())
end

return HydrateEntityReplicationCommand