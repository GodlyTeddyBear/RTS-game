--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local CompleteEntityReplicationBootstrapCommand = {}
CompleteEntityReplicationBootstrapCommand.__index = CompleteEntityReplicationBootstrapCommand
setmetatable(CompleteEntityReplicationBootstrapCommand, BaseCommand)

function CompleteEntityReplicationBootstrapCommand.new()
	local self = BaseCommand.new("Entity", "CompleteEntityReplicationBootstrap")
	return setmetatable(self, CompleteEntityReplicationBootstrapCommand)
end
function CompleteEntityReplicationBootstrapCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_replicationService = "EntityReplicationService",
		_validationService = "EntityValidationService",
	})
end

function CompleteEntityReplicationBootstrapCommand:Execute(player: Player): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "CompleteEntityReplicationBootstrap", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:CompleteBootstrapResult(player)
	end, self:_Label())
end

return CompleteEntityReplicationBootstrapCommand