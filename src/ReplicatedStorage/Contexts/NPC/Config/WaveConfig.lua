--!strict

--[[
    WaveConfig - Config-driven wave definitions per zone.

    Each zone maps to an array of waves. Each wave is an array of enemy groups.
    Enemy groups define an EnemyType (matching EnemyConfig keys) and Count.

    Usage:
        local waves = WaveConfig.GoblinCave
        local wave1Enemies = waves[1] -- { { EnemyType = "Goblin", Count = 3 } }
]]

return table.freeze({
	GoblinCave = table.freeze({
		[1] = table.freeze({
			table.freeze({ EnemyType = "Goblin", Count = 3 }),
		}),
		[2] = table.freeze({
			table.freeze({ EnemyType = "Goblin", Count = 4 }),
			table.freeze({ EnemyType = "Orc", Count = 1 }),
		}),
		[3] = table.freeze({
			table.freeze({ EnemyType = "BossGoblinKing", Count = 1 }),
			table.freeze({ EnemyType = "Goblin", Count = 2 }),
		}),
	}),

	OrcFortress = table.freeze({
		[1] = table.freeze({
			table.freeze({ EnemyType = "Orc", Count = 3 }),
		}),
		[2] = table.freeze({
			table.freeze({ EnemyType = "Orc", Count = 4 }),
			table.freeze({ EnemyType = "Goblin", Count = 2 }),
		}),
		[3] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 1 }),
			table.freeze({ EnemyType = "Orc", Count = 3 }),
		}),
		[4] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 2 }),
			table.freeze({ EnemyType = "Orc", Count = 2 }),
		}),
	}),

	TrollDen = table.freeze({
		[1] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 2 }),
		}),
		[2] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 3 }),
			table.freeze({ EnemyType = "Orc", Count = 1 }),
		}),
		[3] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 3 }),
			table.freeze({ EnemyType = "Orc", Count = 2 }),
		}),
		[4] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 4 }),
		}),
		[5] = table.freeze({
			table.freeze({ EnemyType = "Troll", Count = 3 }),
			table.freeze({ EnemyType = "BossGoblinKing", Count = 1 }),
		}),
	}),
})
