--!strict

--[[
    RangedEnemyBehavior - Behavior tree for ranged enemy NPCs.

    Priority:
    1. Sequence(IncomingAttack, Block)             -- React to committed opponent attacks
    2. Sequence(LowHP + FleeEnabled, Flee)
    3. Sequence(TooClose, Flee)                    -- inside MinAttackRange, back away
    4. Sequence(InRangeBand + NotOnCooldown, RangedAttack)
    5. Sequence(InRangeBandOnly, Idle)             -- Hold position while on cooldown
    6. Sequence(EnemyDetected, Chase)              -- too far, close distance
    7. Wander (fallback)

    Range band logic:
    - Target closer than MinAttackRange -> flee (too close)
    - Target between MinAttackRange and MaxAttackRange -> ranged attack (optimal)
    - Target further than MaxAttackRange -> chase (too far)
    - No target -> wander

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
				Seq(BehaviorNodes.TooCloseCondition(), BehaviorNodes.Flee()), -- Back away if too close
				Seq(BehaviorNodes.InRangeBandCondition(), BehaviorNodes.RangedAttack()), -- Attack in optimal band
				Seq(BehaviorNodes.InRangeBandOnlyCondition(), BehaviorNodes.Idle()), -- Hold position while on cooldown
				Seq(BehaviorNodes.EnemyDetectedCondition(), BehaviorNodes.Chase()), -- Chase if too far
				BehaviorNodes.Wander(), -- Wander as fallback
			},
		}),
	})

	return tree
end

return {
	CreateTree = CreateTree,
}
