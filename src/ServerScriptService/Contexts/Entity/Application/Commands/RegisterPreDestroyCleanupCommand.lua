--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local RegisterPreDestroyCleanupCommand = {}
RegisterPreDestroyCleanupCommand.__index = RegisterPreDestroyCleanupCommand
setmetatable(RegisterPreDestroyCleanupCommand, BaseCommand)

function RegisterPreDestroyCleanupCommand.new()
	local self = BaseCommand.new("Entity", "RegisterPreDestroyCleanup")
	return setmetatable(self, RegisterPreDestroyCleanupCommand)
end

function RegisterPreDestroyCleanupCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_preDestroyCleanupRegistry", "EntityPreDestroyCleanupRegistry")
end

function RegisterPreDestroyCleanupCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		return self._preDestroyCleanupRegistry:RegisterContributor(payload)
	end, self:_Label())
end

return RegisterPreDestroyCleanupCommand
