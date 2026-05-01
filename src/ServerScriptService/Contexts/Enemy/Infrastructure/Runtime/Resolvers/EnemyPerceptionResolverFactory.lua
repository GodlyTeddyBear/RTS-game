--!strict

local EnemyPerceptionResolverFactory = {}

function EnemyPerceptionResolverFactory.Create(dependencies: {
	TargetingResolver: any,
}): any
	return table.freeze({
		CreateProxy = function(): any
			return {
				IsTargetInRange = function(
					_proxy: any,
					position: Vector3,
					attackRange: number,
					targetKind: any,
					targetEntity: number?
				)
					return dependencies.TargetingResolver.IsTargetInRange(position, attackRange, targetKind, targetEntity)
				end,
			}
		end,
	})
end

return table.freeze(EnemyPerceptionResolverFactory)
