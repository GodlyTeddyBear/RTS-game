--!strict

local FLEE_THRESHOLD = 0.2

--[=[
	@class CombatPerceptionService
	Builds the facts snapshot passed into combat behavior trees.
	@server
]=]
local CombatPerceptionService = {}
CombatPerceptionService.__index = CombatPerceptionService

function CombatPerceptionService.new()
	return setmetatable({}, CombatPerceptionService)
end

-- Resolves the enemy entity factory used to inspect path and health state.
function CombatPerceptionService:Init(_registry: any, _name: string)
end

function CombatPerceptionService:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

-- Returns the perception facts a behavior tree needs to decide the next action.
function CombatPerceptionService:BuildSnapshot(entity: number, _currentTime: number)
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	local health = self._enemyEntityFactory:GetHealth(entity)

	local hasWaypoints = pathState ~= nil and pathState.waypoints ~= nil and #pathState.waypoints > 0
	local isAtGoal = false
	if hasWaypoints and pathState then
		isAtGoal = pathState.waypointIndex > #pathState.waypoints
	end

	local healthPct = 1
	if health and health.max > 0 then
		healthPct = math.clamp(health.current / health.max, 0, 1)
	end

	return {
		HasWaypoints = hasWaypoints,
		IsAtGoal = isAtGoal,
		HealthPct = healthPct,
		ShouldFlee = healthPct < FLEE_THRESHOLD,
	}
end

return CombatPerceptionService
