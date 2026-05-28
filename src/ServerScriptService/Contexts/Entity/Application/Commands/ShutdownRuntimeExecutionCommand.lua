--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local ShutdownRuntimeExecutionCommand = {}
ShutdownRuntimeExecutionCommand.__index = ShutdownRuntimeExecutionCommand
setmetatable(ShutdownRuntimeExecutionCommand, BaseCommand)

function ShutdownRuntimeExecutionCommand.new()
	local self = BaseCommand.new("Entity", "ShutdownRuntimeExecution")
	return setmetatable(self, ShutdownRuntimeExecutionCommand)
end

function ShutdownRuntimeExecutionCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_instanceBindingService = "EntityInstanceBindingService",
		_unregisterAIEntityCommand = "UnregisterAIEntityCommand",
		_prepareRuntimeEntityForRemovalCommand = "PrepareRuntimeEntityForRemovalCommand",
	})
end

function ShutdownRuntimeExecutionCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		for _, entity in ipairs(self._aiEntityRegistry:CollectRegisteredEntities()) do
			self._unregisterAIEntityCommand:Execute(entity)
		end

		for _, entity in ipairs(self._runtimeParticipation:CollectRuntimeEntities()) do
			self._prepareRuntimeEntityForRemovalCommand:Execute(entity, true)
		end

		self._instanceBindingService:DestroyAll()
		return Result.Ok(true)
	end, self:_Label())
end

return ShutdownRuntimeExecutionCommand
