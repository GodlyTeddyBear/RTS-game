--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ReplicatedStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local MovementTypes = require(script.Parent.Types)

type EnemyMovementMode = MovementTypes.EnemyMovementMode
type TPathMovementState = MovementTypes.TPathMovementState

local GOAL_POSITION_EPSILON = 0.01

return function(MovementService: any)
	-- Resolves the enemy role name so movement can look up role-specific pathing params.
	function MovementService:_GetRoleName(entity: number): string?
		local role = self._enemyEntityFactory:GetRole(entity)
		return if role ~= nil then role.Role else nil
	end

	-- Returns the agent params for one entity, falling back to the default movement config.
	function MovementService:_GetAgentParams(entity: number): { [string]: any }
		local roleName = self:_GetRoleName(entity)
		if roleName ~= nil then
			local config = CombatMovementConfig.AGENT_PARAMS_BY_ROLE[roleName]
			if config ~= nil then
				return config
			end
		end

		return CombatMovementConfig.DEFAULT_AGENT_PARAMS
	end

	-- Returns the minimum group size required before an "Any" mover can switch to flow.
	function MovementService:_GetMinGroupSize(): number
		local configuredMinGroupSize = BoidsConfig.MinGroupSize
		if type(configuredMinGroupSize) ~= "number" then
			return 2
		end

		return math.max(1, math.floor(configuredMinGroupSize))
	end

	-- Checks whether one entity can use flow movement at the provided goal position.
	function MovementService:_CanEntityUseFlowAtGoal(entity: number, goalPosition: Vector3): boolean
		local pathState = self._enemyEntityFactory:GetPathState(entity)
		if pathState == nil or pathState.GoalPosition == nil then
			return false
		end

		if (pathState.GoalPosition - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
			return false
		end

		local roleName = self:_GetRoleName(entity)
		local roleConfig = if roleName ~= nil then EnemyConfig.Roles[roleName] else nil
		if roleConfig == nil then
			return false
		end

		return roleConfig.MovementMode == "Any" or roleConfig.MovementMode == "Boids"
	end

	-- Counts how many alive entities near the goal are eligible to share the flow runtime.
	function MovementService:_CountFlowEligibleAtGoal(goalPosition: Vector3): number
		local groupSize = 0
		for _, aliveEntity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
			if self:_CanEntityUseFlowAtGoal(aliveEntity, goalPosition) then
				groupSize += 1
			end
		end
		return groupSize
	end

	-- Resolves the concrete movement branch that should handle the current entity.
	function MovementService:_ResolveAdvanceMode(movementMode: EnemyMovementMode, goalPosition: Vector3): ("Path" | "Flow")?
		if movementMode == "Path" then
			return "Path"
		end

		if movementMode == "Boids" then
			return "Flow"
		end

		if movementMode == "Any" then
			return if self:_CountFlowEligibleAtGoal(goalPosition) >= self:_GetMinGroupSize() then "Flow" else "Path"
		end

		return nil
	end

	-- Starts the pathfinding promise for one entity and marks it as path-moving.
	function MovementService:_StartPath(entity: number, goalPosition: Vector3): boolean
		local path = PathfindingHelper.CreatePath(entity, {
			EnemyEntityFactory = self._enemyEntityFactory,
		}, self:_GetAgentParams(entity), CombatMovementConfig.PATHFINDING)
		if path == nil then
			return false
		end

		self._movementByEntity[entity] = {
			Mode = "Path",
			Promise = PathfindingHelper.RunPath(path, goalPosition, entity, CombatMovementConfig.PATHFINDING),
		}
		self._enemyEntityFactory:SetPathMoving(entity, true)
		return true
	end

	-- Polls one path promise and converts the result into a movement lifecycle outcome.
	function MovementService:_TickPath(entity: number, movementState: TPathMovementState): ("Running" | "Success" | "Fail", string?)
		local promise = movementState.Promise
		if promise == nil then
			self:StopMovement(entity)
			return "Fail", "MissingPathPromise"
		end

		local status = promise:getStatus()
		if status == Promise.Status.Started then
			return "Running", nil
		end

		self._movementByEntity[entity] = nil
		self._enemyEntityFactory:SetPathMoving(entity, false)

		if status == Promise.Status.Resolved then
			return "Success", nil
		end

		return "Fail", "PathPromiseRejected"
	end
end
