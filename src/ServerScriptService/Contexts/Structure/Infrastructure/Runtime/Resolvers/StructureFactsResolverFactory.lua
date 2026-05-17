--!strict

local StructureFactsResolverFactory = {}
local COMBAT_STATS_GROUP = "CombatStats"
local SPATIAL_GROUP = "Spatial"

function StructureFactsResolverFactory.Create(dependencies: {
	StructureEntityFactory: any,
	TargetingResolver: any,
}): any
	return table.freeze({
		BuildCheapFactGroups = function(entity: number): { [string]: { BuildFacts: () -> { [string]: any } } }
			return {
				[SPATIAL_GROUP] = {
					BuildFacts = function(): { [string]: any }
						return {
							ActorPosition = dependencies.StructureEntityFactory:GetPosition(entity),
						}
					end,
				},
				[COMBAT_STATS_GROUP] = {
					BuildFacts = function(): { [string]: any }
						local attackStats = dependencies.StructureEntityFactory:GetAttackStats(entity)
						return {
							AttackRange = if attackStats ~= nil then attackStats.AttackRange else nil,
						}
					end,
				},
			}
		end,
		ValidateCachedTarget = function(
			cachedTargetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			},
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			local actorPosition = cheapFacts.ActorPosition
			local attackRange = cheapFacts.AttackRange
			if typeof(actorPosition) ~= "Vector3" or type(attackRange) ~= "number" then
				return nil
			end

			if cachedTargetState.TargetEntity == nil then
				return nil
			end

			if not dependencies.TargetingResolver.IsEnemyTargetInRange(actorPosition, attackRange, cachedTargetState.TargetEntity) then
				return nil
			end

			local targetPosition = dependencies.TargetingResolver.ResolveEnemyTargetPosition(cachedTargetState.TargetEntity)
			if typeof(targetPosition) ~= "Vector3" then
				return nil
			end

			return {
				TargetEntity = cachedTargetState.TargetEntity,
				TargetKind = "Enemy",
				TargetPosition = targetPosition,
			}
		end,
		ReacquireTarget = function(
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			local actorPosition = cheapFacts.ActorPosition
			local attackRange = cheapFacts.AttackRange
			if typeof(actorPosition) ~= "Vector3" or type(attackRange) ~= "number" then
				return nil
			end

			local targetEnemyEntity = dependencies.TargetingResolver.FindNearestEnemyInRange(actorPosition, attackRange)
			if targetEnemyEntity == nil then
				return nil
			end

			local targetPosition = dependencies.TargetingResolver.ResolveEnemyTargetPosition(targetEnemyEntity)
			return {
				TargetEntity = targetEnemyEntity,
				TargetKind = "Enemy",
				TargetPosition = targetPosition,
			}
		end,
		BuildFactSnapshot = function(
			_cheapFacts: { [string]: any },
			targetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			}
		): { [string]: any }
			return {
				TargetEnemyEntity = if targetState.TargetKind == "Enemy" then targetState.TargetEntity else nil,
			}
		end,
	})
end

return table.freeze(StructureFactsResolverFactory)
