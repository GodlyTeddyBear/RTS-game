--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local MovementTypes = require(script.Parent.Types)

type EnemyMovementMode = MovementTypes.EnemyMovementMode
type TAgentParams = MovementTypes.TAgentParams
type TMovementActorKey = MovementTypes.TMovementActorKey
type TMovementActorBinding = MovementTypes.TMovementActorBinding
type TMovementService = MovementTypes.TMovementService
type TPathMovementState = MovementTypes.TPathMovementState

return function(MovementService: TMovementService)
	local function _GetBinding(self: TMovementService, actorKey: TMovementActorKey): TMovementActorBinding?
		return self:_GetMovementBinding(actorKey)
	end

	-- Returns the agent params for one entity, falling back to the default movement config.
	function MovementService:_GetAgentParams(actorKey: TMovementActorKey): TAgentParams
		local binding = _GetBinding(self, actorKey)
		if binding ~= nil then
			return binding:GetAgentParams()
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
	function MovementService:_CountFlowEligibleAtGoal(actorKey: TMovementActorKey, goalPosition: Vector3): number
		local binding = _GetBinding(self, actorKey)
		if binding == nil then
			return 0
		end
		return binding:CountFlowEligiblePeers(goalPosition)
	end

	-- Resolves the concrete movement branch that should handle the current entity.
	function MovementService:_ResolveAdvanceMode(
		actorKey: TMovementActorKey,
		movementMode: EnemyMovementMode,
		goalPosition: Vector3
	): ("Path" | "Flow")?
		if movementMode == "Path" then
			return "Path"
		end

		if movementMode == "Boids" then
			return "Flow"
		end

		if movementMode == "Any" then
			if self:_CountFlowEligibleAtGoal(actorKey, goalPosition) >= self:_GetMinGroupSize() then
				return "Flow"
			end
			return "Path"
		end

		return nil
	end

	-- Starts the pathfinding promise for one entity and marks it as path-moving.
	function MovementService:_StartPath(actorKey: TMovementActorKey, goalPosition: Vector3): boolean
		local binding = _GetBinding(self, actorKey)
		if binding == nil then
			return false
		end
		local entityId = binding.EntityId

		local path = PathfindingHelper.CreatePath(entityId, {
			EntityFactory = {
				GetModelRef = function(_factory: any, requestedEntity: number)
					if requestedEntity ~= entityId then
						return nil
					end
					return binding:GetModelRef()
				end,
			},
		}, self:_GetAgentParams(actorKey), CombatMovementConfig.PATHFINDING)
		if not path then
			return false
		end

		self._movementByActorKey[actorKey] = {
			Mode = "Path",
			Promise = PathfindingHelper.RunPath(path, goalPosition, entityId, CombatMovementConfig.PATHFINDING),
		}
		binding:SetPathMoving(true)
		return true
	end

	-- Polls one path promise and converts the result into a movement lifecycle outcome.
	function MovementService:_TickPath(
		actorKey: TMovementActorKey,
		movementState: TPathMovementState
	): ("Running" | "Success" | "Fail", string?)
		local promise = movementState.Promise
		if not promise then
			local binding = _GetBinding(self, actorKey)
			if binding ~= nil then
				self:StopMovement(binding)
			end
			return "Fail", "MissingPathPromise"
		end

		local status = promise:getStatus()
		if status == Promise.Status.Started then
			return "Running", nil
		end

		self._movementByActorKey[actorKey] = nil
		local binding = _GetBinding(self, actorKey)
		if binding ~= nil then
			binding:SetPathMoving(false)
		end

		if status == Promise.Status.Resolved then
			return "Success", nil
		end

		return "Fail", "PathPromiseRejected"
	end
end
