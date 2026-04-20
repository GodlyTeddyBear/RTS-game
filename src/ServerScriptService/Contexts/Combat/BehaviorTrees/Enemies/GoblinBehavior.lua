--!strict

--[[
    GoblinBehavior - Behavior tree for Goblin enemies (melee).

    Priority:
    1. Sequence(IncomingAttack, Block)    -- React to committed opponent attacks
    2. Sequence(LowHP + FleeEnabled, Flee)
    3. Sequence(InAttackRange + NotOnCooldown, MeleeAttack)
    4. Sequence(InAttackRangeOnly, Idle)  -- Hold position while on cooldown
    5. Sequence(EnemyDetected, Chase)
    6. Wander (fallback)

    Goblins are simple melee rushers - detect, chase, attack.
    Flee is available but disabled by default in BehaviorDefaults (FleeEnabled = false).

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
				Seq(BehaviorNodes.IncomingAttackCondition(), BehaviorNodes.Block()), -- Block incoming committed attacks
				Seq(BehaviorNodes.FleeCondition(), BehaviorNodes.Flee()), -- Flee if low HP
				Seq(BehaviorNodes.InAttackRangeCondition(), BehaviorNodes.MeleeAttack()), -- Attack if in range
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
