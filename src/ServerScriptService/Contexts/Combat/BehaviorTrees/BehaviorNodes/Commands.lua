--!strict

--[[
    Commands - BT command node factories.

    Each function returns a fresh BehaviourTree.Task instance that queues
    an action intent via NPCEntityFactory:SetPendingAction. The actual
    execution is handled by Executor classes, not these nodes.

    Commands consume transient context variables (_SelectedTarget, _ThreatEntity)
    set by paired condition nodes in the same Sequence.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BehaviourTree = require(ReplicatedStorage.Utilities.BehaviorTree)
local WeaponCategoryConfig = require(ReplicatedStorage.Contexts.Combat.Config.WeaponCategoryConfig)

local function Task(fn)
	return BehaviourTree.Task:new({ run = fn })
end

--[[
    CommandFactory - Produces a BT node factory from a declarative config.

    Config fields:
        ActionName : string   - The action ID to queue (e.g. "MeleeAttack")
        ContextKey : string?  - Context variable to read (e.g. "_SelectedTarget"); nil = no lookup
        BuildData  : ((entity: any, ctx: any) -> { [string]: any })?  - Builds the action payload; nil = no payload
]]
type TCommandConfig = {
	ActionName: string,
	ContextKey: string?,
	BuildData: ((entity: any, ctx: any) -> { [string]: any })?,
}

local function CommandFactory(config: TCommandConfig)
	return function()
		return Task(function(task, ctx)
			local entity = if config.ContextKey then ctx[config.ContextKey] else nil
			if config.ContextKey and not entity then
				task:fail()
				return
			end

			local data = if config.BuildData then config.BuildData(entity, ctx) else nil
			ctx.NPCEntityFactory:SetPendingAction(ctx.Entity, config.ActionName, data)
			task:success()
		end)
	end
end

local Commands = {}

Commands.Flee = CommandFactory({
	ActionName = "Flee",
	ContextKey = "_ThreatEntity",
	BuildData = function(entity)
		return { ThreatEntity = entity }
	end,
})

Commands.MeleeAttack = CommandFactory({
	ActionName = "MeleeAttack",
	ContextKey = "_SelectedTarget",
	BuildData = function(entity)
		return { TargetEntity = entity }
	end,
})

Commands.RangedAttack = CommandFactory({
	ActionName = "RangedAttack",
	ContextKey = "_SelectedTarget",
	BuildData = function(entity)
		return { TargetEntity = entity }
	end,
})

-- WeaponAttack reads the entity's WeaponCategoryComponent from ECS,
-- resolves the ActionId from WeaponCategoryConfig, and queues it.
function Commands.WeaponAttack()
	return Task(function(task, ctx)
		local target = ctx._SelectedTarget
		if not target then
			task:fail()
			return
		end

		local weaponComp = ctx.NPCEntityFactory:GetWeaponCategory(ctx.Entity)
		local category = weaponComp and weaponComp.Category or "Punch"
		local profile = WeaponCategoryConfig[category] or WeaponCategoryConfig.Punch
		local actionId = profile.ActionId

		ctx.NPCEntityFactory:SetPendingAction(ctx.Entity, actionId, { TargetEntity = target })
		task:success()
	end)
end

Commands.Block = CommandFactory({
	ActionName = "Block",
})

Commands.Chase = CommandFactory({
	ActionName = "Chase",
	ContextKey = "_SelectedTarget",
	BuildData = function(entity, ctx)
		return {
			TargetEntity = entity,
			MoveTarget = ctx.PerceptionService:GetTargetPosition(entity),
		}
	end,
})

Commands.Idle = CommandFactory({
	ActionName = "Idle",
})

-- Parameterised skill command. Queues the given skillId as a pending action on the entity.
-- Paired with SkillReadyCondition in a Sequence.
-- Usage: Commands.UseSkill("PowerStrike")()
function Commands.UseSkill(skillId: string)
	return CommandFactory({
		ActionName = skillId,
		ContextKey = "_SelectedTarget",
		BuildData = function(entity)
			return { TargetEntity = entity }
		end,
	})
end

-- Wander has conditional fallback logic (nil target → Idle) that doesn't fit CommandFactory.
function Commands.Wander()
	return Task(function(task, ctx)
		local modelRef = ctx.NPCEntityFactory:GetModelRef(ctx.Entity)
		local modelInstance = modelRef and modelRef.Instance or nil
		local wanderTarget = ctx.PerceptionService:GetWanderTarget(ctx.Entity, modelInstance)

		if wanderTarget then
			ctx.NPCEntityFactory:SetPendingAction(ctx.Entity, "Wander", { WanderTarget = wanderTarget })
		else
			ctx.NPCEntityFactory:SetPendingAction(ctx.Entity, "Idle", nil)
		end
		task:success()
	end)
end

return Commands
