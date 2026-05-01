--!strict

local StructureFactsResolverFactory = {}

function StructureFactsResolverFactory.Create(dependencies: {
	StructureEntityFactory: any,
	TargetingResolver: any,
}): any
	return table.freeze({
		BuildFacts = function(entity: number): { [string]: any }
			local attackStats = dependencies.StructureEntityFactory:GetAttackStats(entity)
			local position = dependencies.StructureEntityFactory:GetPosition(entity)
			local targetEnemyEntity = nil :: number?
			if attackStats ~= nil and position ~= nil then
				targetEnemyEntity = dependencies.TargetingResolver.FindNearestEnemyInRange(position, attackStats.AttackRange)
			end

			return {
				TargetEnemyEntity = targetEnemyEntity,
			}
		end,
	})
end

return table.freeze(StructureFactsResolverFactory)
