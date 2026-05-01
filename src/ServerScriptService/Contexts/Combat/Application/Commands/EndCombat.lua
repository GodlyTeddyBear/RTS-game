--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

local EndCombat = {}
EndCombat.__index = EndCombat
setmetatable(EndCombat, BaseCommand)

function EndCombat.new()
	local self = BaseCommand.new("Combat", "EndCombat")
	return setmetatable(self, EndCombat)
end

function EndCombat:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_combatHitResolutionService = "CombatHitResolutionService",
		_hitboxService = "HitboxService",
		_lockOnService = "LockOnService",
		_movementService = "MovementService",
		_projectileService = "ProjectileService",
	})
end

function EndCombat:Execute(userId: number?): Result.Result<boolean>
	return Result.Catch(function()
		local targetUserId = userId
		if targetUserId == nil then
			local primaryPlayer = Players:GetPlayers()[1]
			if primaryPlayer ~= nil then
				targetUserId = primaryPlayer.UserId
			end
		end

		if targetUserId == nil or not self._loopService:HasSession(targetUserId) then
			return Ok(false)
		end

		Try(self._loopService:BeginEndingSession(targetUserId))

		self._hitboxService:CleanupAll()
		self._combatHitResolutionService:CleanupAll()
		self._lockOnService:CleanupAll()
		self._movementService:CleanupAll()
		self._projectileService:CleanupAll()

		Try(self._behaviorRuntimeService:StopRuntime())
		Try(self._loopService:ClearSession(targetUserId))

		return Ok(true)
	end, self:_Label())
end

return EndCombat
