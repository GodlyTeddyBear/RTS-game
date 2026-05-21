--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local StructureTargetingResolverFactory = {}

function StructureTargetingResolverFactory.Create(dependencies: {
	EnemyEntityFactory: any,
	EnemyInstanceFactory: any,
}): any
	local resolver = {}

	function resolver.IsEnemyTargetInRange(position: Vector3, attackRange: number, enemyEntity: number): boolean
			if not dependencies.EnemyEntityFactory:IsAlive(enemyEntity) then
				return false
			end

			local targetPosition = resolver.ResolveEnemyTargetPosition(enemyEntity)
			local enemyModel = dependencies.EnemyInstanceFactory:GetInstance(enemyEntity)
			if targetPosition == nil or enemyModel == nil or not enemyModel:IsA("Model") or enemyModel.Parent == nil then
				return false
			end

			return SpatialQuery.IsWithinRaycastRange(
				position,
				targetPosition,
				attackRange,
				SpatialQuery.MergeOptions(
					SpatialQuery.Presets.CharactersOnly,
					SpatialQuery.Presets.IncludeInstances({ enemyModel })
				),
				0.05
			)
	end

	function resolver.ResolveEnemyTargetPosition(enemyEntity: number): Vector3?
			if not dependencies.EnemyEntityFactory:IsAlive(enemyEntity) then
				return nil
			end

			local enemyModel = dependencies.EnemyInstanceFactory:GetInstance(enemyEntity)
			if enemyModel == nil or not enemyModel:IsA("Model") or enemyModel.Parent == nil then
				return nil
			end

			return ModelPlus.GetCenterPosition(enemyModel)
	end

	function resolver.FindNearestEnemyInRange(position: Vector3, attackRange: number): number?
			return SpatialQuery.FindBestCandidate(
				position,
				dependencies.EnemyEntityFactory:QueryAliveEntities(),
				function(enemyEntity: number): Vector3?
					local enemyCFrame = dependencies.EnemyEntityFactory:GetEntityCFrame(enemyEntity)
					return if enemyCFrame ~= nil then enemyCFrame.Position else nil
				end,
				function(enemyEntity: number, distance: number): number?
					if not resolver.IsEnemyTargetInRange(position, attackRange, enemyEntity) then
						return nil
					end
					return -distance
				end,
				attackRange
			)
	end

	return table.freeze(resolver)
end

return table.freeze(StructureTargetingResolverFactory)
