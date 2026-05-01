--!strict

local StructureProjectileProxyResolverFactory = {}

function StructureProjectileProxyResolverFactory.Create(dependencies: {
	ProjectileService: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			return {
				FireStructureBullet = function(_proxy: any, request: any)
					return dependencies.ProjectileService:FireStructureBullet({
						StructureEntity = entity,
						TargetEnemyEntity = request.TargetEnemyEntity,
						Damage = request.Damage,
						MaxDistance = request.MaxDistance,
					})
				end,
			}
		end,
	})
end

return table.freeze(StructureProjectileProxyResolverFactory)
