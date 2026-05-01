--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local EnemyTargetingResolverFactory = {}

function EnemyTargetingResolverFactory.Create(dependencies: {
	BaseEntityFactory: any,
	StructureEntityFactory: any,
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

				local baseRef = dependencies.BaseEntityFactory:GetInstanceRef()
				if baseRef == nil or baseRef.Instance == nil then
					return nil, nil
				end

				if baseRef.Instance:IsA("Model") then
					return baseRef.Instance, ModelPlus.GetCenterPosition(baseRef.Instance)
				end

				if baseRef.Instance:IsA("BasePart") then
					return baseRef.Instance, baseRef.Instance.Position
				end

				if baseRef.Anchor ~= nil then
					return baseRef.Instance, baseRef.Anchor.Position
				end

				return nil, nil
			end

			if targetKind == "Structure" then
				if targetEntity == nil or not dependencies.StructureEntityFactory:IsActive(targetEntity) then
					return nil, nil
				end

				local modelRef = dependencies.StructureEntityFactory:GetModelRef(targetEntity)
				if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
					return nil, nil
				end
				return modelRef.Model, ModelPlus.GetCenterPosition(modelRef.Model)
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
				dependencies.StructureEntityFactory:QueryActiveEntities(),
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
