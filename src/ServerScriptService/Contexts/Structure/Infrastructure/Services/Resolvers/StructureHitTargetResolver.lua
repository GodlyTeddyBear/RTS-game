--!strict

local StructureHitTargetResolver = {}

function StructureHitTargetResolver.Resolve(enemyInstanceFactory: any, hitPart: BasePart): any?
	local model = hitPart:FindFirstAncestorOfClass("Model")
	if model == nil then
		return nil
	end

	local enemyEntity = enemyInstanceFactory:GetEntity(model)
	if enemyEntity == nil then
		return nil
	end

	return {
		Kind = "Enemy",
		Entity = enemyEntity,
	}
end

return table.freeze(StructureHitTargetResolver)
