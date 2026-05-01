--!strict

local StructureFactoryProxyResolverFactory = {}

function StructureFactoryProxyResolverFactory.Create(dependencies: {
	StructureEntityFactory: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			local factory = dependencies.StructureEntityFactory
			return {
				IsActive = function(_proxy: any, _runtimeId: number): boolean
					return factory:IsActive(entity)
				end,
				GetPosition = function(_proxy: any, _runtimeId: number): Vector3?
					return factory:GetPosition(entity)
				end,
				GetAttackStats = function(_proxy: any, _runtimeId: number)
					return factory:GetAttackStats(entity)
				end,
				GetCooldown = function(_proxy: any, _runtimeId: number)
					return factory:GetCooldown(entity)
				end,
				SetCooldownElapsed = function(_proxy: any, _runtimeId: number, elapsed: number)
					factory:SetCooldownElapsed(entity, elapsed)
				end,
				SetTarget = function(_proxy: any, _runtimeId: number, targetEnemy: number?)
					factory:SetTarget(entity, targetEnemy)
				end,
				GetModelRef = function(_proxy: any, _runtimeId: number)
					return factory:GetModelRef(entity)
				end,
				PromoteToCommitted = function(_proxy: any, _runtimeId: number)
					factory:PromoteToCommitted(entity)
				end,
			}
		end,
	})
end

return table.freeze(StructureFactoryProxyResolverFactory)
