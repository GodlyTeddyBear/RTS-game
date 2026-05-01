--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

type CombatActorPayload = CombatTypes.CombatActorPayload

local Try = Result.Try

local RegisterCombatActorCommand = {}
RegisterCombatActorCommand.__index = RegisterCombatActorCommand
setmetatable(RegisterCombatActorCommand, BaseCommand)

function RegisterCombatActorCommand.new()
	local self = BaseCommand.new("Combat", "RegisterCombatActor")
	return setmetatable(self, RegisterCombatActorCommand)
end

function RegisterCombatActorCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_actorRegistryService = "CombatActorRegistryService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
	})
end

function RegisterCombatActorCommand:Execute(payload: CombatActorPayload): Result.Result<string>
	return Result.Catch(function()
		if not self._actorRegistryService:IsRuntimeStarted() then
			return self._actorRegistryService:QueueActor(payload)
		end

		local behaviorTree = Try(self._behaviorRuntimeService:BuildTree(payload.BehaviorDefinition))
		return self._actorRegistryService:RegisterActor(payload, behaviorTree)
	end, self:_Label())
end

return RegisterCombatActorCommand
