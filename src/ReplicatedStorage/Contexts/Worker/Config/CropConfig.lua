--!strict

--[[
	Crop Configuration

	Defines all growable crop types available in the Farm zone.
	Used by AssignFarmerTarget to validate crop assignments.

	Adding a new crop:
	1. Add a new entry here
	2. Add the corresponding folder in the lot's Zones/Production/Farm/ folder
]]

export type TCropStats = {
	CropId: string,
	DisplayName: string,
	XPPerHarvest: number,
	GrowDuration: number,
	ItemId: string,
	MaxWorkers: number,
}

return table.freeze({
	Wheat = {
		CropId = "Wheat",
		DisplayName = "Wheat",
		XPPerHarvest = 5,
		GrowDuration = 4.0,
		ItemId = "Wheat",
		MaxWorkers = 2,
	} :: TCropStats,
	Potato = {
		CropId = "Potato",
		DisplayName = "Potato",
		XPPerHarvest = 7,
		GrowDuration = 5.0,
		ItemId = "Potato",
		MaxWorkers = 2,
	} :: TCropStats,
	Carrot = {
		CropId = "Carrot",
		DisplayName = "Carrot",
		XPPerHarvest = 6,
		GrowDuration = 4.5,
		ItemId = "Carrot",
		MaxWorkers = 2,
	} :: TCropStats,
	Pumpkin = {
		CropId = "Pumpkin",
		DisplayName = "Pumpkin",
		XPPerHarvest = 12,
		GrowDuration = 7.0,
		ItemId = "Pumpkin",
		MaxWorkers = 1,
	} :: TCropStats,
	Sunflower = {
		CropId = "Sunflower",
		DisplayName = "Sunflower",
		XPPerHarvest = 10,
		GrowDuration = 6.0,
		ItemId = "Sunflower",
		MaxWorkers = 1,
	} :: TCropStats,
})
