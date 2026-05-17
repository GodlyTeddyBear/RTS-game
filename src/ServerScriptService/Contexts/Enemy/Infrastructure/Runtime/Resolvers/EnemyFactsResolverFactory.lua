--!strict

local FLEE_THRESHOLD = 0.2
local NAVIGATION_GROUP = "Navigation"
local SPATIAL_COMBAT_GROUP = "SpatialCombat"
local STATUS_GROUP = "Status"

local EnemyFactsResolverFactory = {}

function EnemyFactsResolverFactory.Create(dependencies: {
	EnemyEntityFactory: any,
	TargetingResolver: any,
}): any
	return table.freeze({
		BuildCheapFactGroups = function(entity: number): { [string]: { BuildFacts: () -> { [string]: any } } }
			return {
				[NAVIGATION_GROUP] = {
					BuildFacts = function(): { [string]: any }
						local pathState = dependencies.EnemyEntityFactory:GetPathState(entity)
						return {
							HasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil,
						}
					end,
				},
				[STATUS_GROUP] = {
					BuildFacts = function(): { [string]: any }
						local health = dependencies.EnemyEntityFactory:GetHealth(entity)
						local healthPct = 1
						if health ~= nil and health.Max > 0 then
							healthPct = math.clamp(health.Current / health.Max, 0, 1)
						end

						return {
							HealthPct = healthPct,
							ShouldFlee = healthPct < FLEE_THRESHOLD,
						}
					end,
				},
				[SPATIAL_COMBAT_GROUP] = {
					BuildFacts = function(): { [string]: any }
						local role = dependencies.EnemyEntityFactory:GetRole(entity)
						local position = dependencies.EnemyEntityFactory:GetPosition(entity)

						return {
							ActorPosition = if position ~= nil then position.CFrame.Position else nil,
							AttackRange = if role ~= nil and type(role.AttackRange) == "number" then role.AttackRange else nil,
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

			if cachedTargetState.TargetKind == "Structure" and cachedTargetState.TargetEntity ~= nil then
				if not dependencies.TargetingResolver.IsTargetInRange(
					actorPosition,
					attackRange,
					"Structure",
					cachedTargetState.TargetEntity
				) then
					return nil
				end

				local _, targetPosition =
					dependencies.TargetingResolver.ResolveTargetRaycastData("Structure", cachedTargetState.TargetEntity)
				if typeof(targetPosition) ~= "Vector3" then
					return nil
				end

				return {
					TargetEntity = cachedTargetState.TargetEntity,
					TargetKind = "Structure",
					TargetPosition = targetPosition,
				}
			end

			if cachedTargetState.TargetKind == "Base" then
				if not dependencies.TargetingResolver.IsTargetInRange(actorPosition, attackRange, "Base", nil) then
					return nil
				end

				local _, targetPosition = dependencies.TargetingResolver.ResolveTargetRaycastData("Base", nil)
				if typeof(targetPosition) ~= "Vector3" then
					return nil
				end

				return {
					TargetEntity = nil,
					TargetKind = "Base",
					TargetPosition = targetPosition,
				}
			end

			return nil
		end,
		ReacquireTarget = function(
			cheapFacts: { [string]: any }
		): { TargetEntity: number?, TargetKind: string?, TargetPosition: Vector3? }?
			local actorPosition = cheapFacts.ActorPosition
			local attackRange = cheapFacts.AttackRange
			if typeof(actorPosition) ~= "Vector3" or type(attackRange) ~= "number" then
				return nil
			end

			local targetStructureEntity = dependencies.TargetingResolver.FindNearestStructureInRange(actorPosition, attackRange)
			if targetStructureEntity ~= nil then
				local _, targetPosition =
					dependencies.TargetingResolver.ResolveTargetRaycastData("Structure", targetStructureEntity)
				return {
					TargetEntity = targetStructureEntity,
					TargetKind = "Structure",
					TargetPosition = targetPosition,
				}
			end

			if dependencies.TargetingResolver.IsTargetInRange(actorPosition, attackRange, "Base", nil) then
				local _, targetPosition = dependencies.TargetingResolver.ResolveTargetRaycastData("Base", nil)
				return {
					TargetEntity = nil,
					TargetKind = "Base",
					TargetPosition = targetPosition,
				}
			end

			return nil
		end,
		BuildFactSnapshot = function(
			cheapFacts: { [string]: any },
			targetState: {
				TargetEntity: number?,
				TargetKind: string?,
				TargetPosition: Vector3?,
			}
		): { [string]: any }
			return {
				HasGoalTarget = cheapFacts.HasGoalTarget,
				HealthPct = cheapFacts.HealthPct,
				ShouldFlee = cheapFacts.ShouldFlee,
				TargetStructureEntity = if targetState.TargetKind == "Structure" then targetState.TargetEntity else nil,
				HasBaseTargetInRange = targetState.TargetKind == "Base",
			}
		end,
	})
end

return table.freeze(EnemyFactsResolverFactory)
