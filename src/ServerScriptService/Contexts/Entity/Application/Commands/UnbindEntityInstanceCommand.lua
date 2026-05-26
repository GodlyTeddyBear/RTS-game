--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local UnbindEntityInstanceCommand = {}
UnbindEntityInstanceCommand.__index = UnbindEntityInstanceCommand
setmetatable(UnbindEntityInstanceCommand, BaseCommand)

function UnbindEntityInstanceCommand.new()
	local self = BaseCommand.new("Entity", "UnbindEntityInstance")
	return setmetatable(self, UnbindEntityInstanceCommand)
end
function UnbindEntityInstanceCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_instanceBindingService = "EntityInstanceBindingService",
		_validationService = "EntityValidationService",
	})
end

function UnbindEntityInstanceCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "UnbindEntityInstance", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._instanceBindingService:UnbindEntityInstance(entity)
	end, self:_Label())
end

return UnbindEntityInstanceCommand