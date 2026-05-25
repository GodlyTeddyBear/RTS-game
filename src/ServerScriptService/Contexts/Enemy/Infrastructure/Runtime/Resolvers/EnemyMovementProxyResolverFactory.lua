--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

local EnemyMovementProxyResolverFactory = {}
local GOAL_POSITION_EPSILON = 0.01

function EnemyMovementProxyResolverFactory.Create(dependencies: {
	MovementService: any,
	EnemyEntityFactory: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			local enemyEntityFactory = dependencies.EnemyEntityFactory
			local binding = {
				ActorKey = "Enemy:" .. tostring(entity),
				EntityId = entity,
				GetPathState = function(self: any)
					return enemyEntityFactory:GetPathState(self.EntityId)
				end,
				SetPathMoving = function(self: any, isMoving: boolean)
					enemyEntityFactory:SetPathMoving(self.EntityId, isMoving)
				end,
				GetModelRef = function(self: any)
					return enemyEntityFactory:GetModelRef(self.EntityId)
				end,
				GetCurrentMoveSpeed = function(self: any)
					return enemyEntityFactory:GetCurrentMoveSpeed(self.EntityId)
				end,
				GetAgentParams = function(self: any)
					local role = enemyEntityFactory:GetRole(self.EntityId)
					local roleName = if role ~= nil then role.Role else nil
					local config =
						if type(roleName) == "string" then CombatMovementConfig.AGENT_PARAMS_BY_ROLE[roleName] else nil
					return if config ~= nil then config else CombatMovementConfig.DEFAULT_AGENT_PARAMS
				end,
				CountFlowEligiblePeers = function(self: any, goalPosition: Vector3): number
					local groupSize = 0
					for _, candidateEntity in ipairs(enemyEntityFactory:QueryAliveEntities()) do
						local pathState = enemyEntityFactory:GetPathState(candidateEntity)
						local candidateGoal = if pathState ~= nil then pathState.GoalPosition else nil
						if candidateGoal == nil then
							continue
						end
						if (candidateGoal - goalPosition).Magnitude > GOAL_POSITION_EPSILON then
							continue
						end

						local role = enemyEntityFactory:GetRole(candidateEntity)
						local roleName = if role ~= nil then role.Role else nil
						local roleConfig = if type(roleName) == "string" then EnemyConfig.Roles[roleName] else nil
						if roleConfig == nil then
							continue
						end
						if roleConfig.MovementMode == "Any" or roleConfig.MovementMode == "Boids" then
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

return table.freeze(EnemyMovementProxyResolverFactory)
