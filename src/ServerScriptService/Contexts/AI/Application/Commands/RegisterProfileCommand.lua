--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)

local RegisterProfileCommand = {}
RegisterProfileCommand.__index = RegisterProfileCommand
setmetatable(RegisterProfileCommand, BaseCommand)

function RegisterProfileCommand.new()
	local self = BaseCommand.new("AI", "RegisterProfile")
	return setmetatable(self, RegisterProfileCommand)
end

function RegisterProfileCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_profileRegistry", "AIEntityProfileRegistry")
end

function RegisterProfileCommand:Execute(payload: any)
	return self._profileRegistry:RegisterProfile(payload)
end

return RegisterProfileCommand
