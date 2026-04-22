--!strict

local FLEE_THRESHOLD = 0.2

--[=[
	@class CombatPerceptionService
	Builds the facts snapshot passed into combat behavior trees.
	@server
]=]
local CombatPerceptionService = {}
CombatPerceptionService.__index = CombatPerceptionService

--[=[
	@within CombatPerceptionService
	Creates a new combat perception service.
	@return CombatPerceptionService -- Service instance used to build behavior facts.
]=]
function CombatPerceptionService.new()
	return setmetatable({}, CombatPerceptionService)
end

--[=[
	@within CombatPerceptionService
	Resolves the enemy entity factory used to inspect path and health state.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatPerceptionService:Init(_registry: any, _name: string)
end

--[=[
	@within CombatPerceptionService
	Stores the enemy entity factory needed to build perception snapshots.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the service.
]=]
function CombatPerceptionService:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

--[=[
	@within CombatPerceptionService
	Returns the perception facts a behavior tree needs to decide the next action.
	@param entity number -- Enemy entity id whose state should be sampled.
	@param _currentTime number -- Current timestamp, reserved for future time-based facts.
	@return table -- Facts snapshot consumed by combat behavior trees.
]=]
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
