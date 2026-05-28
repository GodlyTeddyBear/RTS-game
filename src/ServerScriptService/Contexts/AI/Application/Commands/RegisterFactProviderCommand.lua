--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local RegisterFactProviderCommand = {}
RegisterFactProviderCommand.__index = RegisterFactProviderCommand
setmetatable(RegisterFactProviderCommand, BaseCommand)

function RegisterFactProviderCommand.new()
	local self = BaseCommand.new("AI", "RegisterFactProvider")
	return setmetatable(self, RegisterFactProviderCommand)
end

function RegisterFactProviderCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_factProviderRegistry", "AIFactProviderRegistry")
end

function RegisterFactProviderCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		return self._factProviderRegistry:RegisterFactProvider(payload)
	end, self:_Label())
end

return RegisterFactProviderCommand
