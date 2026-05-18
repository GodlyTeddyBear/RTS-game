--!strict

local EnemyMovementProxyResolverFactory = {}

function EnemyMovementProxyResolverFactory.Create(dependencies: {
	MovementService: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			return {
				StartAdvance = function(_proxy: any, _runtimeId: number, movementMode: any): (boolean, string?)
					return dependencies.MovementService:StartAdvance(entity, movementMode)
				end,
				StepAdvance = function(_proxy: any, _runtimeId: number, services: any?): (boolean, string?)
					return dependencies.MovementService:StepAdvance(entity, services)
				end,
				StopMovement = function(_proxy: any, _runtimeId: number)
					dependencies.MovementService:StopMovement(entity)
				end,
			}
		end,
	})
end

return table.freeze(EnemyMovementProxyResolverFactory)
