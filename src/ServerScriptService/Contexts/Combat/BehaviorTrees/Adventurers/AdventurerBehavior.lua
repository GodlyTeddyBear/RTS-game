--!strict

--[[
    AdventurerBehavior - Unified behavior tree for adventurer NPCs.

    Handles both melee and ranged adventurers in a single tree.
    Weapon-dependent behavior is driven by BehaviorConfig overrides
    applied at StartCombat (from WeaponCategoryConfig).

    Priority:
    1. Sequence(HasPlayerCommand, ExecutePlayerCommand)      -- Player command override
    2. Sequence(FleeCondition, Flee)                         -- Flee if low HP (staff: FleeEnabled=true)
    3. Sequence(TooClose, Flee)                              -- Back away (ranged only: MinAttackRange set)
    4. Sequence(InRangeBand + NotOnCooldown, WeaponAttack)   -- Ranged attack in optimal band
    5. Sequence(InRangeBandOnly, Idle)                       -- Ranged: hold position on cooldown
    6. Sequence(InAttackRange + NotOnCooldown, WeaponAttack) -- Melee attack in range
    7. Sequence(InAttackRangeOnly, Idle)                     -- Melee: hold position on cooldown
    8. Sequence(EnemyDetected, Chase)                        -- Chase if detected
    9. Wander (fallback)

    For melee adventurers (Sword/Dagger/Punch): steps 2-5 always fail
    (FleeEnabled=false, MinAttackRange=nil), so they use steps 6-7.

    For ranged adventurers (Staff): steps 3-5 handle the ranged pattern.
    Steps 6-7 are redundant but harmless (InRangeBand catches all valid ranges first).

    BT nodes read ECS via ctx.PerceptionService (no blackboard).
    BT nodes write pending actions via ctx.NPCEntityFactory:SetPendingAction.
    WeaponAttack reads WeaponCategoryComponent to pick the correct ActionId.
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
				Seq(BehaviorNodes.HasPlayerCommandCondition(), BehaviorNodes.ExecutePlayerCommand()),
				Seq(BehaviorNodes.FleeCondition(), BehaviorNodes.Flee()),
				Seq(BehaviorNodes.TooCloseCondition(), BehaviorNodes.Flee()),
				Seq(BehaviorNodes.InRangeBandCondition(), BehaviorNodes.WeaponAttack()),
				Seq(BehaviorNodes.InRangeBandOnlyCondition(), BehaviorNodes.Idle()),
				Seq(BehaviorNodes.InAttackRangeCondition(), BehaviorNodes.WeaponAttack()),
				Seq(BehaviorNodes.InAttackRangeOnlyCondition(), BehaviorNodes.Idle()),
				Seq(BehaviorNodes.EnemyDetectedCondition(), BehaviorNodes.Chase()),
				BehaviorNodes.Wander(),
			},
		}),
	})

	return tree
end

return {
	CreateTree = CreateTree,
}
