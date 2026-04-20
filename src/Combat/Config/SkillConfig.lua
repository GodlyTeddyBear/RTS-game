--!strict

--[[
	SkillConfig - Mechanical profiles for every skill in the combat system.

	Each entry defines the skill's combat parameters. Skills are identified by
	their SkillId string, which also serves as the executor ActionId and the
	key in SkillSetConfig entries.

	Adding a new skill:
	  1. Add an entry here
	  2. Create a matching executor in Executors/Skills/
	  3. Register the executor in CombatContext:KnitInit
	  4. Add the SkillId to the relevant entries in SkillSetConfig
]]

export type TSkillProfile = {
	SkillId: string,
	DisplayName: string,
	Cooldown: number,
	DamageMultiplier: number?, -- nil = utility skill (no direct damage)
	Range: number?, -- nil = use the entity's configured attack range
}

return table.freeze({
	PowerStrike = table.freeze({
		SkillId = "PowerStrike",
		DisplayName = "Power Strike",
		Cooldown = 8.0,
		DamageMultiplier = 2.5,
		Range = nil,
	} :: TSkillProfile),
})
