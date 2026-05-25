--!strict

--[=[
    @class UnitServiceProxyResolverFactory
    Builds the runtime service proxies that let unit behaviors talk back to unit ECS and movement services.

    @server
]=]

local UnitServiceProxyResolverFactory = {}

-- Creates the proxy bundle used by the behavior runtime to interact with unit ECS and optional movement services.
function UnitServiceProxyResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
	MovementProxyResolver: any?,
	GetRuntimeOwner: (() -> any)?,
	}): any
	return table.freeze({
		-- Builds the per-entity runtime service surface consumed by behavior executors.
		BuildServices = function(entity: number, currentTime: number, tickId: number?): { [string]: any }
			local unitEntityFactory = dependencies.UnitEntityFactory
			local services = {
				CurrentTime = currentTime,
				UnitEntityFactory = {
					ResolveRuntimeEntity = function(_proxy: any, _runtimeId: number): number
						return entity
					end,
					IsActive = function(_proxy: any, _runtimeId: number): boolean
						return unitEntityFactory:IsActive(entity)
					end,
					GetPathState = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetPathState(entity)
					end,
					HasActionableGoal = function(_proxy: any, _runtimeId: number): boolean
						return unitEntityFactory:HasActionableGoal(entity)
					end,
					GetIdentity = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetIdentity(entity)
					end,
					GetPosition = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetPosition(entity)
					end,
					GetAttackCooldown = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetAttackCooldown(entity)
					end,
					GetCombatAction = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetCombatAction(entity)
					end,
					GetBehaviorConfig = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetBehaviorConfig(entity)
					end,
					SetGoalPosition = function(_proxy: any, _runtimeId: number, goalPosition: Vector3)
						unitEntityFactory:SetGoalPosition(entity, goalPosition)
					end,
					ClearGoalPosition = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearGoalPosition(entity)
					end,
					MarkGoalFailedCurrentRevision = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:MarkGoalFailedCurrentRevision(entity)
					end,
					SetTarget = function(
						_proxy: any,
						_runtimeId: number,
						targetEntity: number?,
						targetKind: "Enemy" | "Structure" | "Base"
					)
						unitEntityFactory:SetTarget(entity, targetEntity, targetKind)
					end,
					ClearTarget = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearTarget(entity)
					end,
					SetLastAttackTime = function(_proxy: any, _runtimeId: number, lastAttackTime: number)
						unitEntityFactory:SetLastAttackTime(entity, lastAttackTime)
					end,
					PromoteToCommitted = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:PromoteToCommitted(entity)
					end,
					SetCombatAction = function(_proxy: any, _runtimeId: number, action: any)
						unitEntityFactory:SetCombatAction(entity, action)
					end,
					ClearAction = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearAction(entity)
					end,
					SetBehaviorConfig = function(_proxy: any, _runtimeId: number, config: { TickInterval: number })
						unitEntityFactory:SetBehaviorConfig(entity, config)
					end,
					GetLockOn = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetLockOn(entity)
					end,
					SetLockOn = function(_proxy: any, _runtimeId: number, lockOn: any)
						unitEntityFactory:SetLockOn(entity, lockOn)
					end,
					ClearLockOn = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearLockOn(entity)
					end,
					MarkGoalReached = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:MarkGoalReached(entity)
					end,
					ClearGoalReached = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearGoalReached(entity)
					end,
					SetPathMoving = function(_proxy: any, _runtimeId: number, isMoving: boolean)
						unitEntityFactory:SetPathMoving(entity, isMoving)
					end,
				},
			}

			if dependencies.MovementProxyResolver ~= nil then
				services.MovementService = dependencies.MovementProxyResolver.CreateProxy(entity)
			end
			if type(tickId) == "number" then
				services.TickId = tickId
			end
			if dependencies.GetRuntimeOwner ~= nil then
				services.UnitContext = dependencies.GetRuntimeOwner()
			end

			return services
		end,
	})
end

return table.freeze(UnitServiceProxyResolverFactory)
