--!strict

local MovementSpeedStatusSystem = {}
MovementSpeedStatusSystem.__index = MovementSpeedStatusSystem

function MovementSpeedStatusSystem.new(statusService: any)
	return setmetatable({ _statusService = statusService }, MovementSpeedStatusSystem)
end

function MovementSpeedStatusSystem:Run()
	-- READS: Enemy.AliveTag, Entity.Transform [AUTHORITATIVE], Movement.SpeedState [AUTHORITATIVE]
	-- WRITES: Movement.SpeedState [AUTHORITATIVE]
	self._statusService:EvaluateEnemyMoveSpeedEffects()
end

return MovementSpeedStatusSystem
