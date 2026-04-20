--!strict

--[[
	SkillSetConfig - Innate skill sets per NPC/adventurer type.

	Keys match the NPCType strings used in BehaviorDefaults and EnemyConfig/AdventurerConfig.
	At entity spawn, NPCEntityFactory merges these innate skills with any equipment skills
	(from WeaponCategoryConfig[category].Skills) to build the entity's final SkillSetComponent.

	Adding skills to an entity type:
	  1. Add the SkillId to the relevant entry below
	  2. Ensure the skill has a profile in SkillConfig
	  3. Ensure the executor is registered in CombatContext
]]

export type TSkillSet = {
	Skills: { string },
}

return table.freeze({
	-- Enemy innate skills
	Goblin = table.freeze({ Skills = {} } :: TSkillSet),
	Orc = table.freeze({ Skills = { "PowerStrike" } } :: TSkillSet),
	Troll = table.freeze({ Skills = {} } :: TSkillSet),
	BossGoblinKing = table.freeze({ Skills = { "PowerStrike" } } :: TSkillSet),
	GoblinArcher = table.freeze({ Skills = {} } :: TSkillSet),
	SkeletonMage = table.freeze({ Skills = {} } :: TSkillSet),

	-- Adventurer innate skills
	Warrior = table.freeze({ Skills = { "PowerStrike" } } :: TSkillSet),
	Scout = table.freeze({ Skills = {} } :: TSkillSet),
	Guardian = table.freeze({ Skills = {} } :: TSkillSet),
	Berserker = table.freeze({ Skills = {} } :: TSkillSet),

	-- Fallback for unrecognised types
	DEFAULT = table.freeze({ Skills = {} } :: TSkillSet),
})
