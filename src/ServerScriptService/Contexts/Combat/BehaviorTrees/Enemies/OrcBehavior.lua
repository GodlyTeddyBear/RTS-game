--!strict

--[[
    OrcBehavior - Behavior tree for Orc enemies (melee with skills).

    Priority:
    1. Sequence(IncomingAttack, Block)                          -- React to committed opponent attacks
    2. Sequence(LowHP + FleeEnabled, Flee)
    3. Sequence(SkillReady("PowerStrike") + InAttackRange, PowerStrike)  -- Use skill when ready
    4. Sequence(InAttackRange + NotOnCooldown, MeleeAttack)
    5. Sequence(InAttackRangeOnly, Idle)                        -- Hold position while on cooldown
    6. Sequence(EnemyDetected, Chase)
    7. Wander (fallback)

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
				Seq(BehaviorNodes.FleeCondition(), BehaviorNodes.Flee()), -- Flee if low HP
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
