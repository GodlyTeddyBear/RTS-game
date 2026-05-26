--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local QueueEntityBindCommand = {}
QueueEntityBindCommand.__index = QueueEntityBindCommand
setmetatable(QueueEntityBindCommand, BaseCommand)

function QueueEntityBindCommand.new()
	local self = BaseCommand.new("Entity", "QueueEntityBind")
	return setmetatable(self, QueueEntityBindCommand)
end
function QueueEntityBindCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_instanceBindingService = "EntityInstanceBindingService",
		_validationService = "EntityValidationService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function QueueEntityBindCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "QueueEntityBind", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local participationResult = EntityOperationSupport.RequireRuntimeBindingParticipation(self._runtimeParticipation, entity)
		if not participationResult.success then
			return participationResult
		end

		return self._instanceBindingService:QueueEntityBind(entity)
	end, self:_Label())
end

return QueueEntityBindCommand