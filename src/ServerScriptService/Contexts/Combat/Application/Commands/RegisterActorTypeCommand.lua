--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

type CombatActorTypePayload = CombatTypes.CombatActorTypePayload

local RegisterActorTypeCommand = {}
RegisterActorTypeCommand.__index = RegisterActorTypeCommand
setmetatable(RegisterActorTypeCommand, BaseCommand)

function RegisterActorTypeCommand.new()
	local self = BaseCommand.new("Combat", "RegisterActorType")
	return setmetatable(self, RegisterActorTypeCommand)
end

function RegisterActorTypeCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_actorRegistryService = "CombatActorRegistryService",
	})
end

function RegisterActorTypeCommand:Execute(payload: CombatActorTypePayload): Result.Result<boolean>
	return Result.Catch(function()
		return self._actorRegistryService:RegisterActorType(payload)
	end, self:_Label())
end

return RegisterActorTypeCommand
