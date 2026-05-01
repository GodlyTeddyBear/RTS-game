--!strict

local EnemyHitTargetResolver = {}

function EnemyHitTargetResolver.Resolve(dependencies: {
	BaseEntityFactory: any,
	StructureEntityFactory: any,
}, hitPart: BasePart): any?
	if dependencies.BaseEntityFactory:IsPartOfBase(hitPart) then
		return {
			Kind = "Base",
			Entity = 0,
		}
	end

	local model = hitPart:FindFirstAncestorOfClass("Model")
	if model == nil then
		return nil
	end

	local structureEntity = dependencies.StructureEntityFactory:GetEntityByModel(model)
	if structureEntity == nil then
		return nil
	end

	return {
		Kind = "Structure",
		Entity = structureEntity,
	}
end

return table.freeze(EnemyHitTargetResolver)
