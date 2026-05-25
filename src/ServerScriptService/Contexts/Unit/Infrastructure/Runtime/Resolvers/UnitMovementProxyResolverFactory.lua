--!strict

--[=[
    @class UnitMovementProxyResolverFactory
    Builds behavior-runtime movement proxies that translate unit AI movement requests into ECS updates.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)

local UnitMovementProxyResolverFactory = {}
local GOAL_POSITION_EPSILON = 0.01

-- Creates the movement proxy bundle used by unit behaviors and AI movement tasks.
function UnitMovementProxyResolverFactory.Create(dependencies: {
	MovementService: any,
	UnitEntityFactory: any,
	}): any
	return table.freeze({
		-- Builds the proxy surface used by movement executors for a single unit entity.
		CreateProxy = function(entity: number): any
			local unitEntityFactory = dependencies.UnitEntityFactory
			local binding = {
				ActorKey = "Unit:" .. tostring(entity),
				EntityId = entity,
				GetPathState = function(self: any)
					return unitEntityFactory:GetPathState(self.EntityId)
				end,
				SetPathMoving = function(self: any, isMoving: boolean)
					unitEntityFactory:SetPathMoving(self.EntityId, isMoving)
				end,
				GetModelRef = function(self: any)
					return unitEntityFactory:GetModelRef(self.EntityId)
				end,
				GetCurrentMoveSpeed = function(self: any)
					return unitEntityFactory:GetCurrentMoveSpeed(self.EntityId)
				end,
				GetAgentParams = function(self: any)
					-- Resolve movement tuning from the unit definition so pathing uses the correct agent profile.
					local identity = unitEntityFactory:GetIdentity(self.EntityId)
					local unitId = if identity ~= nil then identity.UnitId else nil
					local definition = if type(unitId) == "string" then UnitConfig.Definitions[unitId] else nil
					local roleName = if definition ~= nil then definition.Role else nil
					local config = if roleName ~= nil then CombatMovementConfig.AGENT_PARAMS_BY_UNIT_ROLE[roleName] else nil
					return if config ~= nil then config else CombatMovementConfig.DEFAULT_AGENT_PARAMS
				end,
				CountFlowEligiblePeers = function(self: any, goalPosition: Vector3): number
					-- Count nearby peers that share the same goal so flow-based movement can adjust its formation size.
					local groupSize = 0
					for _, candidateEntity in ipairs(unitEntityFactory:QueryActiveEntities()) do
						local pathState = unitEntityFactory:GetPathState(candidateEntity)
						local candidateGoal = if pathState ~= nil then pathState.GoalPosition else nil
						if candidateGoal == nil then
							continue
						end
						if (candidateGoal - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
							continue
						end

						local identity = unitEntityFactory:GetIdentity(candidateEntity)
						local unitId = if identity ~= nil then identity.UnitId else nil
						local definition = if type(unitId) == "string" then UnitConfig.Definitions[unitId] else nil
						if definition == nil then
							continue
						end
						if definition.MovementMode == "Any" or definition.MovementMode == "Boids" then
							groupSize += 1
						end
					end
					return groupSize
				end,
			}

			return {
				StartAdvance = function(
					_proxy: any,
					_runtimeId: number,
					movementMode: any,
					goalPosition: Vector3?
				): (boolean, string?)
					return dependencies.MovementService:StartAdvance(binding, movementMode, goalPosition)
				end,
				StepAdvance = function(_proxy: any, _runtimeId: number, services: any?): (boolean, string?)
					return dependencies.MovementService:StepAdvance(binding, services)
				end,
				StopMovement = function(_proxy: any, _runtimeId: number)
					dependencies.MovementService:StopMovement(binding)
				end,
			}
		end,
	})
end

return table.freeze(UnitMovementProxyResolverFactory)
