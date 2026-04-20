--!strict

--[[
	Remote lot expansion areas.

	Each AreaId maps to one Unlock target. The authored remote lot template should
	place locked content at `ExpansionAreas/<RevealGroupName>`.
]]

export type TRemoteLotAreaConditions = {
	Chapter: number?,
	CommissionTier: number?,
	QuestsCompleted: number?,
	Gold: number?,
	WorkerCount: number?,
	SmelterPlaced: boolean?,
	Ch2FirstVictory: boolean?,
}

export type TRemoteLotArea = {
	AreaId: string,
	TargetId: string,
	DisplayName: string,
	Description: string,
	RevealGroupName: string,
	ZoneFolders: { string },
	Conditions: TRemoteLotAreaConditions,
	SortOrder: number,
}

local RemoteLotAreaConfig: { [string]: TRemoteLotArea } = {
	NorthMeadow = {
		AreaId = "NorthMeadow",
		TargetId = "RemoteLot_NorthMeadow",
		DisplayName = "North Meadow",
		Description = "Open more farmland for food and herb production.",
		RevealGroupName = "NorthMeadow",
		ZoneFolders = { "Farm", "Garden" },
		Conditions = {
			Gold = 250,
		},
		SortOrder = 10,
	},

	StoneRidge = {
		AreaId = "StoneRidge",
		TargetId = "RemoteLot_StoneRidge",
		DisplayName = "Stone Ridge",
		Description = "Clear a rocky ridge with more resource work space.",
		RevealGroupName = "StoneRidge",
		ZoneFolders = { "Mines", "Forest" },
		Conditions = {
			Chapter = 2,
			Gold = 500,
		},
		SortOrder = 20,
	},

	ArtisanPlateau = {
		AreaId = "ArtisanPlateau",
		TargetId = "RemoteLot_ArtisanPlateau",
		DisplayName = "Artisan Plateau",
		Description = "Unlock workshop ground for advanced crafting stations.",
		RevealGroupName = "ArtisanPlateau",
		ZoneFolders = { "Forge", "Brewery", "TailorShop" },
		Conditions = {
			Chapter = 2,
			CommissionTier = 2,
			Gold = 1000,
		},
		SortOrder = 30,
	},
}

return table.freeze(RemoteLotAreaConfig)
