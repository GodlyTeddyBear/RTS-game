--!strict

local EnemyHitTargetResolverFactory = {}

function EnemyHitTargetResolverFactory.Create(dependencies: {
	BaseInstanceFactory: any,
	StructureInstanceFactory: any,
}): any
	return table.freeze({
		ResolveHitTarget = function(hitPart: BasePart): any?
			local baseEntity = dependencies.BaseInstanceFactory:ResolveEntity(hitPart)

			if baseEntity ~= nil then
				return {
					Kind = "Base",
					Entity = baseEntity,
				}
			end

			local model = hitPart:FindFirstAncestorOfClass("Model")
			if model == nil then
				return nil
			end

			local structureEntity = dependencies.StructureInstanceFactory:ResolveEntity(model)
			if structureEntity == nil then
				return nil
			end

			return {
				Kind = "Structure",
				Entity = structureEntity,
			}
		end,
	})
end

return table.freeze(EnemyHitTargetResolverFactory)
