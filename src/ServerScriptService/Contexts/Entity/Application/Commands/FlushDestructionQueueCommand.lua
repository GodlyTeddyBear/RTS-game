--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local FlushDestructionQueueCommand = {}
FlushDestructionQueueCommand.__index = FlushDestructionQueueCommand
setmetatable(FlushDestructionQueueCommand, BaseCommand)

function FlushDestructionQueueCommand.new()
	local self = BaseCommand.new("Entity", "FlushDestructionQueue")
	return setmetatable(self, FlushDestructionQueueCommand)
end
function FlushDestructionQueueCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
	})
end

function FlushDestructionQueueCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "FlushDestructionQueue", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:FlushDestroyQueue()
	end, self:_Label())
end

return FlushDestructionQueueCommand