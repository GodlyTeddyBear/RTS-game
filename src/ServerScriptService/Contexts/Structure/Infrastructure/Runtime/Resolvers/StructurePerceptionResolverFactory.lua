--!strict

local StructurePerceptionResolverFactory = {}

function StructurePerceptionResolverFactory.Create(dependencies: {
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
					if targetKind ~= "Enemy" or targetEntity == nil then
						return false
					end
					return dependencies.TargetingResolver.IsEnemyTargetInRange(position, attackRange, targetEntity)
				end,
			}
		end,
	})
end

return table.freeze(StructurePerceptionResolverFactory)
