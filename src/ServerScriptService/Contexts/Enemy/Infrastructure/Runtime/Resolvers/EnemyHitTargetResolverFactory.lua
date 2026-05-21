--!strict

local EnemyHitTargetResolverFactory = {}

function EnemyHitTargetResolverFactory.Create(dependencies: {
	BaseInstanceFactory: any,
	StructureInstanceFactory: any,
}): any
	return table.freeze({
		ResolveHitTarget = function(hitPart: BasePart): any?
			local baseEntity = dependencies.BaseInstanceFactory:GetEntity(hitPart)
			if baseEntity == nil then
				local baseModel = hitPart:FindFirstAncestorOfClass("Model")
				if baseModel ~= nil then
					baseEntity = dependencies.BaseInstanceFactory:GetEntity(baseModel)
				end
			end

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

			local structureEntity = dependencies.StructureInstanceFactory:GetEntity(model)
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
