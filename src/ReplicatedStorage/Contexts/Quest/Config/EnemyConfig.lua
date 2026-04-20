--!strict

-- Enemy stat templates. Config only — no spawning happens here.
return table.freeze({
	Goblin = table.freeze({
		EnemyId = "Goblin",
		DisplayName = "Goblin",
		BaseHP = 15,
		BaseATK = 8,
		BaseDEF = 0,
	}),

	Orc = table.freeze({
		EnemyId = "Orc",
		DisplayName = "Orc",
		BaseHP = 30,
		BaseATK = 12,
		BaseDEF = 3,
	}),

	Troll = table.freeze({
		EnemyId = "Troll",
		DisplayName = "Troll",
		BaseHP = 60,
		BaseATK = 10,
		BaseDEF = 6,
	}),

	BossGoblinKing = table.freeze({
		EnemyId = "BossGoblinKing",
		DisplayName = "Goblin King",
		BaseHP = 120,
		BaseATK = 20,
		BaseDEF = 8,
	}),
})
