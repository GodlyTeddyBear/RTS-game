--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local MovementTypes = require(script.Parent.Types)

type EnemyMovementMode = MovementTypes.EnemyMovementMode
type TAgentParams = MovementTypes.TAgentParams
type TMovementService = MovementTypes.TMovementService
type TPathMovementState = MovementTypes.TPathMovementState

local GOAL_POSITION_EPSILON = 0.01

return function(MovementService: TMovementService)
	-- Resolves the enemy role name so movement can look up role-specific pathing params.
	function MovementService:_GetRoleName(entity: number): string?
		local movementEntityFactory = self._movementEntityFactory
		if movementEntityFactory == nil then
			return nil
		end
		local role = movementEntityFactory:GetRole(entity)
		return role and role.Role or nil
	end

	-- Returns the agent params for one entity, falling back to the default movement config.
	function MovementService:_GetAgentParams(entity: number): TAgentParams
		local roleName = self:_GetRoleName(entity)
		if roleName then
			local config = CombatMovementConfig.AGENT_PARAMS_BY_ROLE[roleName]
			if config then
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
		local movementEntityFactory = self._movementEntityFactory
		if movementEntityFactory == nil then
			return false
		end
		local pathState = movementEntityFactory:GetPathState(entity)
		if not pathState or not pathState.GoalPosition then
			return false
		end

		if (pathState.GoalPosition - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
			return false
		end

		local roleName = self:_GetRoleName(entity)
		local roleConfig = if roleName ~= nil then (EnemyConfig.Roles :: any)[roleName] else nil
		if not roleConfig then
			return false
		end

		return roleConfig.MovementMode == "Any" or roleConfig.MovementMode == "Boids"
	end

	-- Counts how many alive entities near the goal are eligible to share the flow runtime.
	function MovementService:_CountFlowEligibleAtGoal(goalPosition: Vector3): number
		local movementEntityFactory = self._movementEntityFactory
		if movementEntityFactory == nil then
			return 0
		end

		local queryAliveEntities = movementEntityFactory.QueryAliveEntities
		local queryActiveEntities = movementEntityFactory.QueryActiveEntities
		local queryEntities = if type(queryAliveEntities) == "function"
			then queryAliveEntities(movementEntityFactory)
			elseif type(queryActiveEntities) == "function"
			then queryActiveEntities(movementEntityFactory)
			else {}
		local groupSize = 0
		for _, aliveEntity in ipairs(queryEntities) do
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
			if self:_CountFlowEligibleAtGoal(goalPosition) >= self:_GetMinGroupSize() then
				return "Flow"
			end
			return "Path"
		end

		return nil
	end

	-- Starts the pathfinding promise for one entity and marks it as path-moving.
	function MovementService:_StartPath(entity: number, goalPosition: Vector3): boolean
		local movementEntityFactory = self._movementEntityFactory
		if movementEntityFactory == nil then
			return false
		end

		local path = PathfindingHelper.CreatePath(entity, {
			EntityFactory = movementEntityFactory,
		}, self:_GetAgentParams(entity), CombatMovementConfig.PATHFINDING)
		if not path then
			return false
		end

		self._movementByEntity[entity] = {
			Mode = "Path",
			Promise = PathfindingHelper.RunPath(path, goalPosition, entity, CombatMovementConfig.PATHFINDING),
		}
		movementEntityFactory:SetPathMoving(entity, true)
		return true
	end

	-- Polls one path promise and converts the result into a movement lifecycle outcome.
	function MovementService:_TickPath(entity: number, movementState: TPathMovementState): ("Running" | "Success" | "Fail", string?)
		local promise = movementState.Promise
		if not promise then
			self:StopMovement(entity)
			return "Fail", "MissingPathPromise"
		end

		local status = promise:getStatus()
		if status == Promise.Status.Started then
			return "Running", nil
		end

		self._movementByEntity[entity] = nil
		local movementEntityFactory = self._movementEntityFactory
		if movementEntityFactory ~= nil then
			movementEntityFactory:SetPathMoving(entity, false)
		end

		if status == Promise.Status.Resolved then
			return "Success", nil
		end

		return "Fail", "PathPromiseRejected"
	end
end
