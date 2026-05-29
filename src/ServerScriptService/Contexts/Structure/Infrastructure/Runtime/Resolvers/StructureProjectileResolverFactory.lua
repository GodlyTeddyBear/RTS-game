--!strict

local StructureProjectileResolverFactory = {}

function StructureProjectileResolverFactory.Create(dependencies: {
	StructureInstanceFactory: any,
	EnemyContext: any,
	EnemyEntityFactory: any,
	EntityContext: any,
}): any
	return table.freeze({
		ResolveStructureModel = function(structureEntity: number): Model?
			local instance = dependencies.StructureInstanceFactory:GetInstance(structureEntity)
			return if instance ~= nil and instance:IsA("Model") then instance else nil
		end,
		ResolveEnemyCFrame = function(enemyEntity: number): CFrame?
			return dependencies.EnemyEntityFactory:GetEntityCFrame(enemyEntity)
		end,
		ResolveEnemyEntity = function(hitPart: Instance): number?
			local entityResult = dependencies.EntityContext:GetBoundEntity(hitPart)
			return if entityResult.success and type(entityResult.value) == "number" then entityResult.value else nil
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
