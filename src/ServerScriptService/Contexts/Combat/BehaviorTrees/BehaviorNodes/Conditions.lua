--!strict

--[[
    Conditions - BT condition node factories.

    Each function returns a fresh BehaviourTree.Task instance.
    Conditions set transient context variables (_SelectedTarget, _ThreatEntity)
    that paired action nodes consume in the same Sequence.

    Conditions read from ctx.Facts (a PerceptionSnapshot built once per BT tick
    in ProcessCombatTick) — no ECS queries happen during condition evaluation.

    ConditionFactory config:
        ContextKey   : string        - ctx variable to set on success ("_SelectedTarget" or "_ThreatEntity")
        RequireFacts : { string }?   - fact keys that must be true; fails immediately if any are false
        BlockFacts   : { string }?   - fact keys that must be false; fails immediately if any are true
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BehaviourTree = require(ReplicatedStorage.Utilities.BehaviorTree)

local function Task(fn)
	return BehaviourTree.Task:new({ run = fn })
end

type TConditionConfig = {
	ContextKey: string,
	RequireFacts: { string }?,
	BlockFacts: { string }?,
	-- Which fact key to read as the entity written to ContextKey.
	-- Defaults to "NearestEnemy" when omitted.
	EntityKey: string?,
}

local function ConditionFactory(config: TConditionConfig)
	local entityKey = config.EntityKey or "NearestEnemy"
	return function()
		return Task(function(task, ctx)
			-- All required facts must be true
			if config.RequireFacts then
				for _, key in config.RequireFacts do
					if not ctx.Facts[key] then
						task:fail()
						return
					end
				end
			end

			local entity = ctx.Facts[entityKey]
			if not entity then
				task:fail()
				return
			end

			-- All blocking facts must be false
			if config.BlockFacts then
				for _, key in config.BlockFacts do
					if ctx.Facts[key] then
						task:fail()
						return
					end
				end
			end

			ctx[config.ContextKey] = entity
			task:success()
		end)
	end
end

local Conditions = {}

-- Flee if HP is below threshold. Sets ctx._ThreatEntity.
Conditions.FleeCondition = ConditionFactory({
	ContextKey   = "_ThreatEntity",
	RequireFacts = { "ShouldFlee" },
})

-- Attack when in melee range and off cooldown. Sets ctx._SelectedTarget.
Conditions.InAttackRangeCondition = ConditionFactory({
	ContextKey   = "_SelectedTarget",
	RequireFacts = { "InAttackRange" },
	BlockFacts   = { "AttackOnCooldown" },
})

-- Attack when in ranged band and off cooldown. Sets ctx._SelectedTarget.
Conditions.InRangeBandCondition = ConditionFactory({
	ContextKey   = "_SelectedTarget",
	RequireFacts = { "InRangeBand" },
	BlockFacts   = { "AttackOnCooldown" },
})

-- Back away when target is inside minimum range. Sets ctx._ThreatEntity.
Conditions.TooCloseCondition = ConditionFactory({
	ContextKey   = "_ThreatEntity",
	RequireFacts = { "TooClose" },
})

-- In melee range but on cooldown — hold position. Sets ctx._SelectedTarget.
Conditions.InAttackRangeOnlyCondition = ConditionFactory({
	ContextKey   = "_SelectedTarget",
	RequireFacts = { "InAttackRange" },
})

-- In ranged band but on cooldown — hold position. Sets ctx._SelectedTarget.
Conditions.InRangeBandOnlyCondition = ConditionFactory({
	ContextKey   = "_SelectedTarget",
	RequireFacts = { "InRangeBand" },
})

-- Enemy is visible — chase. Sets ctx._SelectedTarget.
Conditions.EnemyDetectedCondition = ConditionFactory({
	ContextKey = "_SelectedTarget",
})

-- Incoming attack committed by an opponent (hitbox live). Sets ctx._SelectedTarget.
-- Use to trigger a reactive block before the hit lands.
Conditions.IncomingAttackCondition = ConditionFactory({
	ContextKey   = "_SelectedTarget",
	RequireFacts = { "IncomingAttack" },
})

-- Parameterised skill-ready condition.
-- Succeeds when the entity is in melee attack range and the given skill is off cooldown.
-- Sets ctx._SelectedTarget to the nearest enemy.
-- Usage: Conditions.SkillReadyCondition("PowerStrike")()
function Conditions.SkillReadyCondition(skillId: string)
	return function()
		return Task(function(task, ctx)
			local facts = ctx.Facts
			if not facts then
				task:fail()
				return
			end
			if not facts.InAttackRange then
				task:fail()
				return
			end
			if not (facts.SkillsReady and facts.SkillsReady[skillId]) then
				task:fail()
				return
			end
			local target = facts.NearestEnemy
			if not target then
				task:fail()
				return
			end
			ctx._SelectedTarget = target
			task:success()
		end)
	end
end

return Conditions
