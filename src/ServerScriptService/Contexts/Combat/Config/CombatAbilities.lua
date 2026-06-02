--!strict

local CombatAbilities = {
	EnemyBaseAttack = {
		AbilityId = "EnemyBaseAttack",
		Mechanic = "DirectDamage",
		Cooldown = 1.25,
		Startup = 0,
		Active = 0,
		Recovery = 0,
	},

	EnemyStructureAttack = {
		AbilityId = "EnemyStructureAttack",
		Mechanic = "DirectDamage",
		Cooldown = 1.25,
		Startup = 0,
		Active = 0,
		Recovery = 0,
	},

	StructureBullet = {
		AbilityId = "StructureBullet",
		Mechanic = "Projectile",
		ProjectileId = "Bullet",
		Cooldown = 1.2,
		Startup = 0,
		Active = 0,
		Recovery = 0,
		Damage = 1,
		Range = 100,
	},
}

return table.freeze(CombatAbilities)
