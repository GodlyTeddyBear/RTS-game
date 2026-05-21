--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local NotifyActorRemovedCommand = {}
NotifyActorRemovedCommand.__index = NotifyActorRemovedCommand
setmetatable(NotifyActorRemovedCommand, BaseCommand)

function NotifyActorRemovedCommand.new()
	local self = BaseCommand.new("Combat", "NotifyActorRemoved")
	return setmetatable(self, NotifyActorRemovedCommand)
end

function NotifyActorRemovedCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_unregisterCombatActorCommand = "UnregisterCombatActorCommand",
	})
end

function NotifyActorRemovedCommand:Execute(actorHandle: string): Result.Result<boolean>
	return Result.Catch(function()
		return self._unregisterCombatActorCommand:Execute(actorHandle)
	end, self:_Label())
end

return NotifyActorRemovedCommand
