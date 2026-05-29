--!strict

local StructureHitTargetResolverFactory = {}

function StructureHitTargetResolverFactory.Create(dependencies: {
	EntityContext: any,
	EnemyEntityFactory: any,
}): any
	return table.freeze({
		ResolveHitTarget = function(hitPart: BasePart): any?
			local entityResult = dependencies.EntityContext:GetBoundEntity(hitPart)
			if not entityResult.success or type(entityResult.value) ~= "number" then
				return nil
			end
			if not dependencies.EnemyEntityFactory:IsAlive(entityResult.value) then
				return nil
			end

			return {
				Kind = "Enemy",
				Entity = entityResult.value,
			}
		end,
	})
end

return table.freeze(StructureHitTargetResolverFactory)
