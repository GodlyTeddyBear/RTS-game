--!strict

local StructureProjectileResolverFactory = {}

function StructureProjectileResolverFactory.Create(dependencies: {
	StructureEntityFactory: any,
	EnemyContext: any,
	EnemyEntityFactory: any,
	EnemyInstanceFactory: any,
}): any
	return table.freeze({
		ResolveStructureModel = function(structureEntity: number): Model?
			local modelRef = dependencies.StructureEntityFactory:GetModelRef(structureEntity)
			return if modelRef ~= nil then modelRef.Model else nil
		end,
		ResolveEnemyCFrame = function(enemyEntity: number): CFrame?
			return dependencies.EnemyEntityFactory:GetEntityCFrame(enemyEntity)
		end,
		ResolveEnemyEntity = function(hitPart: Instance): number?
			local model = hitPart:FindFirstAncestorOfClass("Model")
			if model == nil then
				return nil
			end

			return dependencies.EnemyInstanceFactory:GetEntity(model)
		end,
		IsEnemyAlive = function(enemyEntity: number): boolean
			return dependencies.EnemyEntityFactory:IsAlive(enemyEntity)
		end,
		ApplyEnemyDamage = function(enemyEntity: number, damage: number)
			dependencies.EnemyContext:ApplyDamage(enemyEntity, damage)
		end,
	})
end

return table.freeze(StructureProjectileResolverFactory)
