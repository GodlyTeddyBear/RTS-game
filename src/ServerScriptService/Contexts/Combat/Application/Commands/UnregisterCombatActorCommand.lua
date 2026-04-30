--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Try = Result.Try

local UnregisterCombatActorCommand = {}
UnregisterCombatActorCommand.__index = UnregisterCombatActorCommand
setmetatable(UnregisterCombatActorCommand, BaseCommand)

function UnregisterCombatActorCommand.new()
	local self = BaseCommand.new("Combat", "UnregisterCombatActor")
	return setmetatable(self, UnregisterCombatActorCommand)
end

function UnregisterCombatActorCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_actorRegistryService = "CombatActorRegistryService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
	})
end

function UnregisterCombatActorCommand:Execute(actorHandle: string): Result.Result<boolean>
	return Result.Catch(function()
		local record = self._actorRegistryService:GetRecordByHandle(actorHandle)
		if record ~= nil then
			self._behaviorRuntimeService:CancelActorAction(record.ActorType, record.RuntimeId, {
				CurrentTime = os.clock(),
				DeltaTime = 0,
				Services = {
					CombatActorRegistryService = self._actorRegistryService,
				},
				ActorTypes = {
					record.ActorType,
				},
			})
		end

		return Try(self._actorRegistryService:UnregisterCombatActor(actorHandle))
	end, self:_Label())
end

return UnregisterCombatActorCommand
