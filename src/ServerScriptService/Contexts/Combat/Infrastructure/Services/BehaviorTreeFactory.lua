--!strict

--[[
    BehaviorTreeFactory - Creates behavior tree instances per NPC type.

    Responsibilities:
    - Map NPC types to behavior tree modules
    - Create fresh BT instances for each NPC
    - Support both adventurer and enemy NPC types

    Pattern: Infrastructure layer service
]]

local AdventurerBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.Adventurers.AdventurerBehavior)
local GoblinBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.Enemies.GoblinBehavior)
local OrcBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.Enemies.OrcBehavior)
local TrollBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.Enemies.TrollBehavior)
local BossBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.Enemies.BossBehavior)
local RangedEnemyBehavior = require(script.Parent.Parent.Parent.BehaviorTrees.Enemies.RangedEnemyBehavior)

local BehaviorTreeFactory = {}
BehaviorTreeFactory.__index = BehaviorTreeFactory

export type TBehaviorTreeFactory = typeof(setmetatable({}, BehaviorTreeFactory))

-- Map NPC types to their behavior tree module
local BEHAVIOR_MAP: { [string]: any } = {
	-- Adventurer types (all use the same default adventurer BT for now)
	Warrior = AdventurerBehavior,
	Scout = AdventurerBehavior,
	Guardian = AdventurerBehavior,
	Berserker = AdventurerBehavior,

	-- Enemy types (melee)
	Goblin = GoblinBehavior,
	Orc = OrcBehavior,
	Troll = TrollBehavior,
	BossGoblinKing = BossBehavior,

	-- Enemy types (ranged)
	GoblinArcher = RangedEnemyBehavior,
	SkeletonMage = RangedEnemyBehavior,
}

function BehaviorTreeFactory.new(): TBehaviorTreeFactory
	local self = setmetatable({}, BehaviorTreeFactory)
	return self
end

--[[
    Create a behavior tree instance for an NPC type.

    @param npcType string - NPC type (e.g., "Warrior", "Goblin")
    @param isAdventurer boolean - Whether this NPC is an adventurer (for fallback)
    @return BehaviourTree instance, or nil if type unknown
]]
function BehaviorTreeFactory:CreateTree(npcType: string, isAdventurer: boolean): any?
	local behaviorModule = BEHAVIOR_MAP[npcType]

	if not behaviorModule then
		-- Fallback: adventurers use AdventurerBehavior, enemies use GoblinBehavior
		if isAdventurer then
			behaviorModule = AdventurerBehavior
		else
			behaviorModule = GoblinBehavior
		end
		warn("[BehaviorTreeFactory] No behavior for type '" .. npcType .. "', using fallback")
	end

	local tree = behaviorModule.CreateTree()
	return tree
end

return BehaviorTreeFactory
