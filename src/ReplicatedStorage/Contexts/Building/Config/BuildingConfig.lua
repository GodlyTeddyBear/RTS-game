--!strict

export type TBuildingDef = {
	Cost: { [string]: number },
	MaxLevel: number,
	CompanionModel: string?, -- asset name to clone alongside the building model
	CompanionFolder: string?, -- child folder name within the zone folder to parent the companion into
	--- ItemId consumed as fuel; burn time per unit is `FuelBurnDurationSeconds`.
	FuelItemId: string?,
	FuelBurnDurationSeconds: number?,
}

export type TZoneDef = {
	MaxSlots: number,
	Buildings: { [string]: TBuildingDef },
	IsRemote: boolean, -- true = separate area, player teleports
}

local BuildingConfig: { [string]: TZoneDef } = {
	Forge = {
		MaxSlots = 3,
		IsRemote = false,
		Buildings = {
			Anvil = {
				Cost = { Gold = 10 },
				MaxLevel = 3,
			},
			WorkBench = {
				Cost = { Gold = 12 },
				MaxLevel = 3,
			},
			Bellows = {
				Cost = { Gold = 15 },
				MaxLevel = 3,
			},
			Smelter = {
				Cost = { Gold = 150 },
				MaxLevel = 1,
				FuelItemId = "Charcoal",
				FuelBurnDurationSeconds = 8,
			},
		},
	},
	Brewery = {
		MaxSlots = 2,
		IsRemote = false,
		Buildings = {
			BrewKettle = {
				Cost = { Gold = 120 },
				MaxLevel = 1,
			},
			FermentingBarrel = {
				Cost = { Gold = 12 },
				MaxLevel = 3,
			},
			StorageRack = {
				Cost = { Gold = 8 },
				MaxLevel = 3,
			},
		},
	},
	TailorShop = {
		MaxSlots = 2,
		IsRemote = false,
		Buildings = {
			LoomTable = {
				Cost = { Gold = 10 },
				MaxLevel = 3,
			},
			DyeVat = {
				Cost = { Gold = 8 },
				MaxLevel = 3,
			},
		},
	},
	Farm = {
		MaxSlots = 4,
		IsRemote = true,
		Buildings = {
			WheatField = {
				Cost = { Gold = 5 },
				MaxLevel = 5,
				CompanionModel = "Wheat",
				CompanionFolder = "Plants",
			},
			CornField = {
				Cost = { Gold = 8 },
				MaxLevel = 5,
				CompanionModel = "Corn",
				CompanionFolder = "Plants",
			},
		},
	},
	Garden = {
		MaxSlots = 4,
		IsRemote = true,
		Buildings = {
			HerbPatch = {
				Cost = { Gold = 6 },
				MaxLevel = 5,
				CompanionModel = "HerbPlant",
				CompanionFolder = "Plants",
			},
			FlowerBed = {
				Cost = { Gold = 4 },
				MaxLevel = 5,
				CompanionModel = "FlowerBed",
				CompanionFolder = "Plants",
			},
		},
	},
	Forest = {
		MaxSlots = 3,
		IsRemote = true,
		Buildings = {
			LumberjackMachine = {
				Cost = { Gold = 20 },
				MaxLevel = 1,
				FuelItemId = "Wood",
				FuelBurnDurationSeconds = 8,
			},
			LoggingPost = {
				Cost = { Gold = 10 },
				MaxLevel = 4,
			},
			Sawmill = {
				Cost = { Gold = 20 },
				MaxLevel = 4,
			},
		},
	},
	Mines = {
		MaxSlots = 3,
		IsRemote = true,
		Buildings = {
			MineShaft = {
				Cost = { Gold = 15 },
				MaxLevel = 5,
			},
			OreProcessingTable = {
				Cost = { Gold = 20 },
				MaxLevel = 4,
			},
		},
	},
}

return BuildingConfig
