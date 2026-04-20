--!strict

--[[
    PlayerCommandNodes - BT nodes for player command integration.

    HasPlayerCommandCondition: Custom Task (not ConditionFactory — needs ECS read,
    not PerceptionService). Checks if the entity has a PlayerCommandComponent.
    Sets ctx._PlayerCommand for the paired ExecutePlayerCommand node.

    ExecutePlayerCommand: Maps CommandType to a pending action and clears the command.
    Each handler returns (actionName, data) or nil on failure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BehaviourTree = require(ReplicatedStorage.Utilities.BehaviorTree)

local function Task(fn)
	return BehaviourTree.Task:new({ run = fn })
end

local function resolveTargetEntity(ctx, targetNPCId: number): any?
	local team = ctx.NPCEntityFactory:GetTeam(ctx.Entity)
	local userId = team and team.UserId or 0
	return ctx.NPCEntityFactory:GetEntityByNPCId(userId, targetNPCId)
end

local function findNearestEnemy(ctx): any?
	local team = ctx.NPCEntityFactory:GetTeam(ctx.Entity)
	local userId = team and team.UserId or 0
	local aliveEnemies = ctx.NPCEntityFactory:QueryAliveEnemies(userId)
	if #aliveEnemies == 0 then
		return nil
	end

	local modelRef = ctx.NPCEntityFactory:GetModelRef(ctx.Entity)
	if not modelRef or not modelRef.Instance or not modelRef.Instance.PrimaryPart then
		return nil
	end

	local myPos = modelRef.Instance.PrimaryPart.Position
	local nearest, nearestDist = nil, math.huge
	for _, enemy in ipairs(aliveEnemies) do
		local enemyRef = ctx.NPCEntityFactory:GetModelRef(enemy)
		if enemyRef and enemyRef.Instance and enemyRef.Instance.PrimaryPart then
			local dist = (enemyRef.Instance.PrimaryPart.Position - myPos).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = enemy
			end
		end
	end
	return nearest
end

local function buildChaseData(ctx, targetEntity: any): { [string]: any }
	return {
		TargetEntity = targetEntity,
		MoveTarget = ctx.PerceptionService:GetTargetPosition(targetEntity),
	}
end

-- Each handler returns (actionName, data) or nil on failure.
local CommandHandlers: { [string]: (ctx: any, commandData: any) -> (string?, { [string]: any }?) } = {
	MoveToPosition = function(_ctx, commandData)
		return "MoveToPosition", {
			Position = commandData and commandData.Position or nil,
			CommandGroupId = commandData and commandData.CommandGroupId or nil,
		}
	end,

	AttackTarget = function(ctx, commandData)
		local targetNPCId = commandData and commandData.TargetNPCId
		if not targetNPCId then
			print("[BT:AttackTarget] no targetNPCId in commandData")
			return nil, nil
		end
		local targetEntity = resolveTargetEntity(ctx, targetNPCId)
		if not targetEntity then
			return nil, nil
		end
		return "Chase", buildChaseData(ctx, targetEntity)
	end,

	HoldPosition = function()
		return "Idle", nil
	end,

	AttackNearest = function(ctx)
		local nearest = findNearestEnemy(ctx)
		if not nearest then
			return nil, nil
		end
		return "Chase", buildChaseData(ctx, nearest)
	end,
}

local PlayerCommandNodes = {}

function PlayerCommandNodes.HasPlayerCommandCondition()
	return Task(function(task, ctx)
		local cmdComp = ctx.NPCEntityFactory:GetPlayerCommand(ctx.Entity)
		if not cmdComp or not cmdComp.CommandType then
			task:fail()
			return
		end

		ctx._PlayerCommand = cmdComp
		task:success()
	end)
end

function PlayerCommandNodes.ExecutePlayerCommand()
	return Task(function(task, ctx)
		local cmd = ctx._PlayerCommand
		if not cmd or not cmd.CommandType then
			task:fail()
			return
		end

		local handler = CommandHandlers[cmd.CommandType]
		if not handler then
			task:fail()
			return
		end

		local actionName, actionData = handler(ctx, cmd.CommandData)
		if not actionName then
			task:fail()
			return
		end

		ctx.NPCEntityFactory:SetPendingAction(ctx.Entity, actionName, actionData)
		ctx.NPCEntityFactory:ClearPlayerCommand(ctx.Entity)
		task:success()
	end)
end

return PlayerCommandNodes
