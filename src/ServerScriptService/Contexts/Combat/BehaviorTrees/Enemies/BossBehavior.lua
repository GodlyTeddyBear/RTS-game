--!strict

--[[
    BossBehavior - Behavior tree for Boss enemies (melee with skills).

    Priority:
    1. Sequence(IncomingAttack, Block)                          -- React to committed opponent attacks
    2. Sequence(SkillReady("PowerStrike") + InAttackRange, PowerStrike)  -- Use skill when ready
    3. Sequence(InAttackRange + NotOnCooldown, MeleeAttack)
    4. Sequence(InAttackRangeOnly, Idle)                        -- Hold position while on cooldown
    5. Sequence(EnemyDetected, Chase)
    6. Wander (fallback)

    Bosses have FleeEnabled = false and a higher FleeHPThreshold = 0 so the flee branch
    never triggers — it is omitted here for clarity.

    Boss-specific phases can be added later by replacing this module with a multi-phase
    tree that hot-swaps subtrees based on HP thresholds.

    BT nodes read ECS via ctx.PerceptionService (no blackboard).
    BT nodes write pending actions via ctx.NPCEntityFactory:SetPendingAction.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BehaviourTree = require(ReplicatedStorage.Utilities.BehaviorTree)

local BehaviorNodes = require(script.Parent.Parent.BehaviorNodes)

local function Seq(...)
	return BehaviourTree.Sequence:new({ nodes = { ... } })
end

local function CreateTree()
	local tree = BehaviourTree:new({
		tree = BehaviourTree.Priority:new({
			nodes = {
				Seq(BehaviorNodes.IncomingAttackCondition(), BehaviorNodes.Block()), -- Block incoming attacks
				Seq(BehaviorNodes.SkillReadyCondition("PowerStrike")(), BehaviorNodes.UseSkill("PowerStrike")()), -- Power Strike when ready
				Seq(BehaviorNodes.InAttackRangeCondition(), BehaviorNodes.MeleeAttack()), -- Normal melee attack
				Seq(BehaviorNodes.InAttackRangeOnlyCondition(), BehaviorNodes.Idle()), -- Hold position while on cooldown
				Seq(BehaviorNodes.EnemyDetectedCondition(), BehaviorNodes.Chase()), -- Chase if detected
				BehaviorNodes.Wander(), -- Wander as fallback
			},
		}),
	})

	return tree
end

return {
	CreateTree = CreateTree,
}
