--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local RegisterActionDefinitionCommand = {}
RegisterActionDefinitionCommand.__index = RegisterActionDefinitionCommand
setmetatable(RegisterActionDefinitionCommand, BaseCommand)

function RegisterActionDefinitionCommand.new()
	local self = BaseCommand.new("AI", "RegisterActionDefinition")
	return setmetatable(self, RegisterActionDefinitionCommand)
end

function RegisterActionDefinitionCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_actionRegistry", "AIActionDefinitionRegistry")
end

function RegisterActionDefinitionCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		return self._actionRegistry:RegisterActionDefinition(payload)
	end, self:_Label())
end

return RegisterActionDefinitionCommand
