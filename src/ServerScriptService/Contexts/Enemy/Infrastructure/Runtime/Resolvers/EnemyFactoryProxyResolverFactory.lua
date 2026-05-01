--!strict

local EnemyFactoryProxyResolverFactory = {}

function EnemyFactoryProxyResolverFactory.Create(dependencies: {
	EnemyEntityFactory: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			local factory = dependencies.EnemyEntityFactory
			return {
				ResolveRuntimeEntity = function(_proxy: any, _runtimeId: number): number
					return entity
				end,
				GetPathState = function(_proxy: any, _runtimeId: number)
					return factory:GetPathState(entity)
				end,
				GetRole = function(_proxy: any, _runtimeId: number)
					return factory:GetRole(entity)
				end,
				GetModelRef = function(_proxy: any, _runtimeId: number)
					return factory:GetModelRef(entity)
				end,
				GetPosition = function(_proxy: any, _runtimeId: number)
					return factory:GetPosition(entity)
				end,
				GetAttackCooldown = function(_proxy: any, _runtimeId: number)
					return factory:GetAttackCooldown(entity)
				end,
				SetTarget = function(
					_proxy: any,
					_runtimeId: number,
					targetEntity: number?,
					targetKind: "Structure" | "Enemy" | "Base"
				)
					factory:SetTarget(entity, targetEntity, targetKind)
				end,
				ClearTarget = function(_proxy: any, _runtimeId: number)
					factory:ClearTarget(entity)
				end,
				SetLastAttackTime = function(_proxy: any, _runtimeId: number, lastAttackTime: number)
					factory:SetLastAttackTime(entity, lastAttackTime)
				end,
				PromoteToCommitted = function(_proxy: any, _runtimeId: number)
					factory:PromoteToCommitted(entity)
				end,
			}
		end,
	})
end

return table.freeze(EnemyFactoryProxyResolverFactory)
