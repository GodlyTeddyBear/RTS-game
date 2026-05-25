--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EnemyMeleeResolverFactory = {}

function EnemyMeleeResolverFactory.Create(dependencies: {
	BaseContext: any,
	BaseEntityFactory: any,
	StructureContext: any,
	StructureEntityFactory: any,
}): any
	return table.freeze({
		IsBaseActive = function(): boolean
			return dependencies.BaseEntityFactory:IsActive()
		end,
		IsStructureActive = function(structureEntity: number): boolean
			return dependencies.StructureEntityFactory:IsTargetable(structureEntity)
		end,
		ApplyBaseDamage = function(damage: number): Result.Result<boolean>
			return dependencies.BaseContext:ApplyDamage(damage)
		end,
		ApplyStructureDamage = function(structureEntity: number, damage: number): Result.Result<boolean>
			return dependencies.StructureContext:ApplyDamage(structureEntity, damage)
		end,
	})
end

return table.freeze(EnemyMeleeResolverFactory)
