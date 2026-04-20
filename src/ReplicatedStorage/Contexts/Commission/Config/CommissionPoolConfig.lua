--!strict

return table.freeze({
	-- Tier 1: Basic materials
	{
		PoolId = "T1_IronOre",
		Tier = 1,
		ItemId = "IronOre",
		MinQty = 3,
		MaxQty = 8,
		BaseGold = 30,
		BaseTkn = 1,
	},
	{
		PoolId = "T1_CopperOre",
		Tier = 1,
		ItemId = "CopperOre",
		MinQty = 3,
		MaxQty = 8,
		BaseGold = 30,
		BaseTkn = 1,
	},
	{
		PoolId = "T1_Stone",
		Tier = 1,
		ItemId = "Stone",
		MinQty = 5,
		MaxQty = 10,
		BaseGold = 20,
		BaseTkn = 1,
	},

	-- Tier 2: Refined materials + basic equipment
	{
		PoolId = "T2_IronPlate",
		Tier = 2,
		ItemId = "IronPlate",
		MinQty = 2,
		MaxQty = 5,
		BaseGold = 60,
		BaseTkn = 2,
	},
	{
		PoolId = "T2_CopperPlate",
		Tier = 2,
		ItemId = "CopperPlate",
		MinQty = 2,
		MaxQty = 5,
		BaseGold = 50,
		BaseTkn = 2,
	},
	{
		PoolId = "T2_WoodenSword",
		Tier = 2,
		ItemId = "WoodenSword",
		MinQty = 1,
		MaxQty = 2,
		BaseGold = 80,
		BaseTkn = 2,
	},
	{
		PoolId = "T2_LeatherArmor",
		Tier = 2,
		ItemId = "LeatherArmor",
		MinQty = 1,
		MaxQty = 2,
		BaseGold = 90,
		BaseTkn = 2,
	},

	-- Tier 3: Crafted equipment + consumables
	{
		PoolId = "T3_IronSword",
		Tier = 3,
		ItemId = "IronSword",
		MinQty = 1,
		MaxQty = 3,
		BaseGold = 150,
		BaseTkn = 3,
	},
	{
		PoolId = "T3_IronArmor",
		Tier = 3,
		ItemId = "IronArmor",
		MinQty = 1,
		MaxQty = 2,
		BaseGold = 200,
		BaseTkn = 3,
	},
	{
		PoolId = "T3_HealingPotion",
		Tier = 3,
		ItemId = "HealingPotion",
		MinQty = 3,
		MaxQty = 6,
		BaseGold = 120,
		BaseTkn = 3,
	},
})
