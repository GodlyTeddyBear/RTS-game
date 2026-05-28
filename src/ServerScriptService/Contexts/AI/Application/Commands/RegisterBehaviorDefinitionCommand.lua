--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local RegisterBehaviorDefinitionCommand = {}
RegisterBehaviorDefinitionCommand.__index = RegisterBehaviorDefinitionCommand
setmetatable(RegisterBehaviorDefinitionCommand, BaseCommand)

function RegisterBehaviorDefinitionCommand.new()
	local self = BaseCommand.new("AI", "RegisterBehaviorDefinition")
	return setmetatable(self, RegisterBehaviorDefinitionCommand)
end

function RegisterBehaviorDefinitionCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_behaviorRegistry", "AIBehaviorDefinitionRegistry")
end

function RegisterBehaviorDefinitionCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		return self._behaviorRegistry:RegisterDefinition(payload)
	end, self:_Label())
end

return RegisterBehaviorDefinitionCommand
