--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EnemyGoalAssignmentResolverFactory = {}

function EnemyGoalAssignmentResolverFactory.Create(dependencies: {
	BaseContext: any,
	EnemyEntityFactory: any,
}): any
	return table.freeze({
		AssignGoalPosition = function(entity: number, actorHandle: string, roleName: string)
			local baseTargetResult = dependencies.BaseContext:GetBaseTargetCFrame()
			if not baseTargetResult.success or baseTargetResult.value == nil then
				Result.MentionError("Enemy:RegisterActor", "Enemy goal position could not be assigned", {
					ActorHandle = actorHandle,
					Role = roleName,
					GoalPositionAssigned = false,
					CauseType = if not baseTargetResult.success then baseTargetResult.type else "MissingBaseTargetCFrame",
					CauseMessage = if not baseTargetResult.success
						then baseTargetResult.message
						else "Base target CFrame was nil during enemy registration",
				}, if not baseTargetResult.success then baseTargetResult.type else "MissingBaseTargetCFrame")
				return
			end

			dependencies.EnemyEntityFactory:SetGoalPosition(entity, baseTargetResult.value.Position)
		end,
	})
end

return table.freeze(EnemyGoalAssignmentResolverFactory)
