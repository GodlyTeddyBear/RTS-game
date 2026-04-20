--!strict

--[[
	Plant Configuration

	Defines all harvestable plant types available in the Garden zone.
	Used by AssignHerbalistTarget to validate plant assignments.

	Adding a new plant:
	1. Add a new entry here
	2. Add the corresponding folder in the lot's Zones/Production/Garden/ folder
]]

export type TPlantStats = {
	PlantId: string,
	DisplayName: string,
	XPPerHarvest: number,
	HarvestDuration: number,
	ItemId: string,
	MaxWorkers: number,
}

return table.freeze({
	HerbPlant = {
		PlantId = "HerbPlant",
		DisplayName = "Herb Plant",
		XPPerHarvest = 6,
		HarvestDuration = 2.0,
		ItemId = "Herb",
		MaxWorkers = 2,
	} :: TPlantStats,
	Mushroom = {
		PlantId = "Mushroom",
		DisplayName = "Mushroom",
		XPPerHarvest = 8,
		HarvestDuration = 2.5,
		ItemId = "Mushroom",
		MaxWorkers = 2,
	} :: TPlantStats,
	Flax = {
		PlantId = "Flax",
		DisplayName = "Flax",
		XPPerHarvest = 10,
		HarvestDuration = 3.0,
		ItemId = "Silk",
		MaxWorkers = 3,
	} :: TPlantStats,
	Nightshade = {
		PlantId = "Nightshade",
		DisplayName = "Nightshade",
		XPPerHarvest = 15,
		HarvestDuration = 4.0,
		ItemId = "Nightshade",
		MaxWorkers = 1,
	} :: TPlantStats,
	Glowroot = {
		PlantId = "Glowroot",
		DisplayName = "Glowroot",
		XPPerHarvest = 20,
		HarvestDuration = 5.0,
		ItemId = "Glowroot",
		MaxWorkers = 1,
	} :: TPlantStats,
})
