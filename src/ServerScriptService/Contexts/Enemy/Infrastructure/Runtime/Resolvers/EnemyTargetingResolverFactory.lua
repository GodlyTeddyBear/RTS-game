--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local EnemyTargetingResolverFactory = {}

function EnemyTargetingResolverFactory.Create(dependencies: {
	BaseEntityFactory: any,
	BaseInstanceFactory: any,
	StructureEntityFactory: any,
	StructureInstanceFactory: any,
}): any
	local resolver = {}

	function resolver.ResolveTargetRaycastData(
		targetKind: "Base" | "Structure" | "Enemy",
		targetEntity: number?
	): (Instance?, Vector3?)
		if targetKind == "Base" then
			if not dependencies.BaseEntityFactory:IsActive() then
				return nil, nil
			end

			local baseEntity = dependencies.BaseEntityFactory:GetBaseEntity()
			if baseEntity == nil then
				return nil, nil
			end

			local baseInstance = dependencies.BaseInstanceFactory:GetBaseInstance(baseEntity)
			if baseInstance == nil then
				return nil, nil
			end

			if baseInstance:IsA("Model") then
				return baseInstance, ModelPlus.GetCenterPosition(baseInstance)
			end

			if baseInstance:IsA("BasePart") then
				return baseInstance, baseInstance.Position
			end

			local baseAnchor = dependencies.BaseInstanceFactory:GetBaseAnchor(baseEntity)
			if baseAnchor ~= nil then
				return baseInstance, baseAnchor.Position
			end

			return nil, nil
		end

		if targetKind == "Structure" then
			if targetEntity == nil or not dependencies.StructureEntityFactory:IsTargetable(targetEntity) then
				return nil, nil
			end

			local structureModel = dependencies.StructureInstanceFactory:GetInstance(targetEntity)
			if structureModel == nil or not structureModel:IsA("Model") or structureModel.Parent == nil then
				return nil, nil
			end

			return structureModel, ModelPlus.GetCenterPosition(structureModel)
		end

		return nil, nil
	end

	function resolver.IsTargetInRange(
		position: Vector3,
		attackRange: number,
		targetKind: "Base" | "Structure" | "Enemy",
		targetEntity: number?
	): boolean
		local targetInstance, targetPosition = resolver.ResolveTargetRaycastData(targetKind, targetEntity)
		if targetInstance == nil or targetPosition == nil then
			return false
		end

		if targetKind == "Base" then
			local overlappingParts = SpatialQuery.OverlapRadius(
				position,
				attackRange,
				SpatialQuery.Presets.IncludeInstances({ targetInstance })
			)
			if #overlappingParts > 0 then
				return true
			end
		end

		return SpatialQuery.IsWithinRaycastRange(
			position,
			targetPosition,
			attackRange,
			SpatialQuery.MergeOptions(
				SpatialQuery.Presets.CharactersOnly,
				SpatialQuery.Presets.IncludeInstances({ targetInstance })
			),
			0.05
		)
	end

	function resolver.FindNearestStructureInRange(position: Vector3, attackRange: number): number?
		return SpatialQuery.FindBestCandidate(
			position,
			dependencies.StructureEntityFactory:QueryTargetableEntities(),
			function(structureEntity: number): Vector3?
				return dependencies.StructureEntityFactory:GetPosition(structureEntity)
			end,
			function(structureEntity: number, distance: number): number?
				if not resolver.IsTargetInRange(position, attackRange, "Structure", structureEntity) then
					return nil
				end
				return -distance
			end,
			attackRange
		)
	end

	return table.freeze(resolver)
end

return table.freeze(EnemyTargetingResolverFactory)
