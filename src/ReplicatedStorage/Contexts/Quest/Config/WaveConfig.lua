--!strict

-- Wave composition per zone.
-- Structure: { [ZoneId]: { [waveNumber]: { { EnemyId, Count } } } }
-- Config only — no spawning happens here.
return table.freeze({
	GoblinCave = table.freeze({
		[1] = table.freeze({ table.freeze({ EnemyId = "Goblin", Count = 2 }) }),
		[2] = table.freeze({ table.freeze({ EnemyId = "Goblin", Count = 2 }) }),
		[3] = table.freeze({
			table.freeze({ EnemyId = "Goblin", Count = 2 }),
			table.freeze({ EnemyId = "BossGoblinKing", Count = 1 }),
		}),
	}),

	OrcFortress = table.freeze({
		[1] = table.freeze({ table.freeze({ EnemyId = "Goblin", Count = 3 }) }),
		[2] = table.freeze({ table.freeze({ EnemyId = "Orc", Count = 2 }) }),
		[3] = table.freeze({ table.freeze({ EnemyId = "Orc", Count = 3 }) }),
		[4] = table.freeze({
			table.freeze({ EnemyId = "Orc", Count = 2 }),
			table.freeze({ EnemyId = "Goblin", Count = 2 }),
		}),
	}),

	TrollDen = table.freeze({
		[1] = table.freeze({ table.freeze({ EnemyId = "Goblin", Count = 4 }) }),
		[2] = table.freeze({ table.freeze({ EnemyId = "Orc", Count = 3 }) }),
		[3] = table.freeze({ table.freeze({ EnemyId = "Troll", Count = 2 }) }),
		[4] = table.freeze({
			table.freeze({ EnemyId = "Orc", Count = 2 }),
			table.freeze({ EnemyId = "Troll", Count = 2 }),
		}),
		[5] = table.freeze({
			table.freeze({ EnemyId = "Troll", Count = 2 }),
			table.freeze({ EnemyId = "BossGoblinKing", Count = 1 }),
		}),
	}),
})
