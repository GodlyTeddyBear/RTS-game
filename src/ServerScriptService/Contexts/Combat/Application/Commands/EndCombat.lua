--!strict

--[=[
	@class EndCombat
	Stops the combat runtime and clears runtime-owned services at session teardown.
	@server
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

local EndCombat = {}
EndCombat.__index = EndCombat
setmetatable(EndCombat, BaseCommand)

--[=[
	Creates a combat teardown command instance.
	@within EndCombat
	@return EndCombat -- New command instance.
]=]
function EndCombat.new()
	local self = BaseCommand.new("Combat", "EndCombat")
	return setmetatable(self, EndCombat)
end

--[=[
	Resolves the combat command dependencies used during teardown.
	@within EndCombat
	@param registry any -- Registry supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function EndCombat:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_combatHitResolutionService = "CombatHitResolutionService",
		_hitboxService = "HitboxService",
		_lockOnService = "LockOnService",
		_movementService = "MovementService",
		_projectileService = "ProjectileService",
		_statusService = "StatusService",
	})
end

--[=[
	Ends the active combat session and clears all runtime-owned state.
	@within EndCombat
	@param userId number? -- Optional combat session owner to end; falls back to the first player.
	@return Result.Result<boolean> -- Whether the teardown ran successfully.
]=]
function EndCombat:Execute(userId: number?): Result.Result<boolean>
	return Result.Catch(function()
		-- Resolve the combat owner when the caller does not pass one explicitly.
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

		-- Enter shutdown before tearing down runtime-owned services.
		Try(self._loopService:BeginEndingSession(targetUserId))

		self._hitboxService:CleanupAll()
		self._combatHitResolutionService:CleanupAll()
		self._lockOnService:CleanupAll()
		self._movementService:CleanupAll()
		self._projectileService:CleanupAll()
		-- Clear all status sources before the runtime is fully stopped.
		self._statusService:ClearAll()

		-- Stop the runtime before clearing the final session record.
		Try(self._behaviorRuntimeService:StopRuntime())
		Try(self._loopService:ClearSession(targetUserId))

		return Ok(true)
	end, self:_Label())
end

return EndCombat
