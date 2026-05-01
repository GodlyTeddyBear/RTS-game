--!strict

local FLEE_THRESHOLD = 0.2

local EnemyFactsResolverFactory = {}

function EnemyFactsResolverFactory.Create(dependencies: {
	EnemyEntityFactory: any,
	TargetingResolver: any,
}): any
	return table.freeze({
		BuildFacts = function(entity: number, _currentTime: number): { [string]: any }
			local pathState = dependencies.EnemyEntityFactory:GetPathState(entity)
			local health = dependencies.EnemyEntityFactory:GetHealth(entity)
			local role = dependencies.EnemyEntityFactory:GetRole(entity)
			local position = dependencies.EnemyEntityFactory:GetPosition(entity)

			local healthPct = 1
			if health ~= nil and health.Max > 0 then
				healthPct = math.clamp(health.Current / health.Max, 0, 1)
			end

			local targetStructureEntity = nil :: number?
			if role ~= nil and position ~= nil and type(role.AttackRange) == "number" then
				targetStructureEntity = dependencies.TargetingResolver.FindNearestStructureInRange(
					position.CFrame.Position,
					role.AttackRange
				)
			end

			local hasBaseTargetInRange = false
			if targetStructureEntity == nil and role ~= nil and position ~= nil and type(role.AttackRange) == "number" then
				hasBaseTargetInRange = dependencies.TargetingResolver.IsTargetInRange(
					position.CFrame.Position,
					role.AttackRange,
					"Base",
					nil
				)
			end

			return {
				HasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil,
				HealthPct = healthPct,
				ShouldFlee = healthPct < FLEE_THRESHOLD,
				TargetStructureEntity = targetStructureEntity,
				HasBaseTargetInRange = hasBaseTargetInRange,
			}
		end,
	})
end

return table.freeze(EnemyFactsResolverFactory)
