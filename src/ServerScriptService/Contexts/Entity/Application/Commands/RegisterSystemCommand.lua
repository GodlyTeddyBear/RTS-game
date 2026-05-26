--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterSystemCommand = {}
RegisterSystemCommand.__index = RegisterSystemCommand
setmetatable(RegisterSystemCommand, BaseCommand)

function RegisterSystemCommand.new()
	local self = BaseCommand.new("Entity", "RegisterSystem")
	return setmetatable(self, RegisterSystemCommand)
end
function RegisterSystemCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_systemRegistry = "EntitySystemRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
	})
end

function RegisterSystemCommand:Execute(phaseName: string, systemSpec: any): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterSystem", self._lifecycle:GetState(), {
			"RegisteringECS",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RegisterSystem(phaseName, systemSpec)
	end, self:_Label())
end

return RegisterSystemCommand