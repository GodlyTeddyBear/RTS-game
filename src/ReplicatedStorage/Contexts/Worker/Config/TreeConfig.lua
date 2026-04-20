--!strict

--[[
	Tree Configuration

	Defines all choppable tree types available in the Forest zone.
	Used by AssignLumberjackTarget to validate tree assignments.

	Adding a new tree:
	1. Add a new entry here
	2. Add the corresponding folder in the lot's Zones/Production/Forest/ folder
]]

export type TTreeStats = {
	TreeId: string,
	DisplayName: string,
	XPPerChop: number,
	ChopDuration: number,
	ItemId: string,
	MaxWorkers: number,
}

return table.freeze({
	Oak = {
		TreeId = "Oak",
		DisplayName = "Oak Tree",
		XPPerChop = 8,
		ChopDuration = 3.0,
		ItemId = "Wood",
		MaxWorkers = 3,
	} :: TTreeStats,
	Pine = {
		TreeId = "Pine",
		DisplayName = "Pine Tree",
		XPPerChop = 12,
		ChopDuration = 3.5,
		ItemId = "Timber",
		MaxWorkers = 2,
	} :: TTreeStats,
	Birch = {
		TreeId = "Birch",
		DisplayName = "Birch Tree",
		XPPerChop = 10,
		ChopDuration = 3.2,
		ItemId = "Plank",
		MaxWorkers = 2,
	} :: TTreeStats,
	Mahogany = {
		TreeId = "Mahogany",
		DisplayName = "Mahogany Tree",
		XPPerChop = 20,
		ChopDuration = 5.0,
		ItemId = "Hardwood",
		MaxWorkers = 1,
	} :: TTreeStats,
	Willow = {
		TreeId = "Willow",
		DisplayName = "Willow Tree",
		XPPerChop = 15,
		ChopDuration = 4.0,
		ItemId = "WillowWood",
		MaxWorkers = 2,
	} :: TTreeStats,
})
