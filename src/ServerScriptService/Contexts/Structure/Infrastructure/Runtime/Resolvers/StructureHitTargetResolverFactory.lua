--!strict

local StructureHitTargetResolverFactory = {}

function StructureHitTargetResolverFactory.Create(dependencies: {
	EnemyInstanceFactory: any,
}): any
	return table.freeze({
		ResolveHitTarget = function(hitPart: BasePart): any?
			local model = hitPart:FindFirstAncestorOfClass("Model")
			if model == nil then
				return nil
			end

			local enemyEntity = dependencies.EnemyInstanceFactory:ResolveEntity(model)
			if enemyEntity == nil then
				return nil
			end

			return {
				Kind = "Enemy",
				Entity = enemyEntity,
			}
		end,
	})
end

return table.freeze(StructureHitTargetResolverFactory)
