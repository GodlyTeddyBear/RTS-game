--!strict

--[[
	WeaponCategoryConfig - Per-weapon-category attack profile definitions.

	Maps weapon category strings (from ItemData.WeaponType) to attack parameters.
	Combat systems use this to determine ActionId, hitbox key, range overrides,
	cooldown, damage multiplier, and whether the unit behaves as ranged.

	Adding a new weapon category:
	  1. Add an entry here
	  2. Add a matching HitboxConfig entry (keyed by ActionId)
	  3. Add an executor file via AttackExecutorFactory({ ActionId = ... })
	  4. Register the executor in CombatContext:KnitInit
	  5. Set WeaponType on the item in ItemConfig
]]

export type TWeaponProfile = {
	ActionId: string,
	HitboxConfigKey: string,
	IsRanged: boolean,
	AttackEnterRange: number,
	AttackExitRange: number,
	MinAttackRange: number?,
	MaxAttackRange: number?,
	FleeEnabled: boolean,
	Cooldown: number,
	DamageMultiplier: number,
	Skills: { string }?, -- Skill IDs granted by this weapon category
}

local Punch: TWeaponProfile = {
	ActionId = "PunchAttack",
	HitboxConfigKey = "PunchAttack",
	IsRanged = false,
	AttackEnterRange = 3,
	AttackExitRange = 5,
	MinAttackRange = nil,
	MaxAttackRange = nil,
	FleeEnabled = false,
	Cooldown = 2.0,
	DamageMultiplier = 0.5,
}

local Sword: TWeaponProfile = {
	ActionId = "SwordAttack",
	HitboxConfigKey = "SwordAttack",
	IsRanged = false,
	AttackEnterRange = 5,
	AttackExitRange = 7,
	MinAttackRange = nil,
	MaxAttackRange = nil,
	FleeEnabled = false,
	Cooldown = 1.5,
	DamageMultiplier = 1.0,
	Skills = { "PowerStrike" },
}

local Dagger: TWeaponProfile = {
	ActionId = "DaggerAttack",
	HitboxConfigKey = "DaggerAttack",
	IsRanged = false,
	AttackEnterRange = 4,
	AttackExitRange = 6,
	MinAttackRange = nil,
	MaxAttackRange = nil,
	FleeEnabled = false,
	Cooldown = 0.9,
	DamageMultiplier = 1.0,
}

local Staff: TWeaponProfile = {
	ActionId = "StaffAttack",
	HitboxConfigKey = "StaffAttack",
	IsRanged = true,
	AttackEnterRange = 15,
	AttackExitRange = 18,
	MinAttackRange = 8,
	MaxAttackRange = 20,
	FleeEnabled = true,
	Cooldown = 2.0,
	DamageMultiplier = 1.0,
}

return table.freeze({
	Punch = table.freeze(Punch),
	Sword = table.freeze(Sword),
	Dagger = table.freeze(Dagger),
	Staff = table.freeze(Staff),
})
