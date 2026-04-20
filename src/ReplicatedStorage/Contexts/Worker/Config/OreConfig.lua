--!strict

--[[
	Ore Configuration

	Defines all mineable ore types available in the Mine zone.
	Used by AssignMinerOre to validate ore assignments.

	Adding a new ore:
	1. Add a new entry here
	2. Add the corresponding folder in the lot's Zones/Production/Mines/ folder
]]

export type TOreStats = {
	OreId: string,
	DisplayName: string,
	XPPerMine: number,
	MiningDuration: number,
	ItemId: string,
	MaxWorkers: number,
}

return table.freeze({
	Iron = {
		OreId = "Iron",
		DisplayName = "Iron Ore",
		XPPerMine = 15,
		MiningDuration = 3.0,
		ItemId = "IronOre",
		MaxWorkers = 3,
	} :: TOreStats,
	Copper = {
		OreId = "Copper",
		DisplayName = "Copper Ore",
		XPPerMine = 10,
		MiningDuration = 2.5,
		ItemId = "CopperOre",
		MaxWorkers = 3,
	} :: TOreStats,
	Stone = {
		OreId = "Stone",
		DisplayName = "Stone Ore",
		XPPerMine = 5,
		MiningDuration = 2.0,
		ItemId = "Stone",
		MaxWorkers = 4,
	} :: TOreStats,
	Coal = {
		OreId = "Coal",
		DisplayName = "Coal",
		XPPerMine = 12,
		MiningDuration = 2.8,
		ItemId = "Coal",
		MaxWorkers = 3,
	} :: TOreStats,
	Gold = {
		OreId = "Gold",
		DisplayName = "Gold Ore",
		XPPerMine = 25,
		MiningDuration = 5.0,
		ItemId = "GoldOre",
		MaxWorkers = 2,
	} :: TOreStats,
	Crystal = {
		OreId = "Crystal",
		DisplayName = "Crystal",
		XPPerMine = 30,
		MiningDuration = 6.0,
		ItemId = "Crystal",
		MaxWorkers = 1,
	} :: TOreStats,
	Herb = {
		OreId = "Herb",
		DisplayName = "Herb",
		XPPerMine = 8,
		MiningDuration = 2.0,
		ItemId = "Herb",
		MaxWorkers = 3,
	} :: TOreStats,
	Silk = {
		OreId = "Silk",
		DisplayName = "Silk",
		XPPerMine = 18,
		MiningDuration = 4.0,
		ItemId = "Silk",
		MaxWorkers = 2,
	} :: TOreStats,
})
