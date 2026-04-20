--!strict

return table.freeze({
	GoblinCave = table.freeze({
		ZoneId = "GoblinCave",
		DisplayName = "Goblin Cave",
		Description = "A dank cave crawling with goblins. A good starting challenge.",
		Tier = 1,
		MinPartySize = 1,
		MaxPartySize = 3,
		WaveCount = 3,
		RecommendedATK = 10,
		RecommendedDEF = 4,
		LootTableId = "LootTable_GoblinCave",
		BaseGoldMin = 20,
		BaseGoldMax = 50,
	}),

	OrcFortress = table.freeze({
		ZoneId = "OrcFortress",
		DisplayName = "Orc Fortress",
		Description = "A fortified stronghold overrun by orcs. Bring your best gear.",
		Tier = 2,
		MinPartySize = 2,
		MaxPartySize = 4,
		WaveCount = 4,
		RecommendedATK = 15,
		RecommendedDEF = 8,
		LootTableId = "LootTable_OrcFortress",
		BaseGoldMin = 60,
		BaseGoldMax = 120,
	}),

	TrollDen = table.freeze({
		ZoneId = "TrollDen",
		DisplayName = "Troll Den",
		Description = "Deep mountain caverns where ancient trolls have made their home.",
		Tier = 3,
		MinPartySize = 2,
		MaxPartySize = 5,
		WaveCount = 5,
		RecommendedATK = 22,
		RecommendedDEF = 14,
		LootTableId = "LootTable_TrollDen",
		BaseGoldMin = 150,
		BaseGoldMax = 300,
	}),
})
