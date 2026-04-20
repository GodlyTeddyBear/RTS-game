--!strict

-- Loot drop tables per zone.
-- Structure: { [LootTableId]: { { ItemId, Weight, MinQty, MaxQty } } }
-- Weight is relative — higher weight = more likely to drop.
return table.freeze({
	LootTable_GoblinCave = table.freeze({
		table.freeze({ ItemId = "IronOre", Weight = 50, MinQty = 2, MaxQty = 6 }),
		table.freeze({ ItemId = "Stone", Weight = 35, MinQty = 3, MaxQty = 8 }),
		table.freeze({ ItemId = "CopperOre", Weight = 15, MinQty = 1, MaxQty = 4 }),
	}),

	LootTable_OrcFortress = table.freeze({
		table.freeze({ ItemId = "IronOre", Weight = 40, MinQty = 4, MaxQty = 10 }),
		table.freeze({ ItemId = "CopperOre", Weight = 30, MinQty = 3, MaxQty = 8 }),
		table.freeze({ ItemId = "CopperPlate", Weight = 20, MinQty = 1, MaxQty = 3 }),
		table.freeze({ ItemId = "LeatherArmor", Weight = 10, MinQty = 1, MaxQty = 1 }),
	}),

	LootTable_TrollDen = table.freeze({
		table.freeze({ ItemId = "IronOre", Weight = 30, MinQty = 6, MaxQty = 15 }),
		table.freeze({ ItemId = "CopperPlate", Weight = 25, MinQty = 2, MaxQty = 5 }),
		table.freeze({ ItemId = "IronArmor", Weight = 20, MinQty = 1, MaxQty = 1 }),
		table.freeze({ ItemId = "IronSword", Weight = 15, MinQty = 1, MaxQty = 1 }),
		table.freeze({ ItemId = "CopperOre", Weight = 10, MinQty = 5, MaxQty = 12 }),
	}),
})
