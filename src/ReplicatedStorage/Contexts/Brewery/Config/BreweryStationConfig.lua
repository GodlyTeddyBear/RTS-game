--!strict

export type TBreweryStation = "BrewKettle"

export type TBreweryStationInfo = {
	BuildingType: string,
	BuildingUnlockId: string,
}

local BreweryStationConfig: { [TBreweryStation]: TBreweryStationInfo } = {
	BrewKettle = {
		BuildingType = "BrewKettle",
		BuildingUnlockId = "Brewery_BrewKettle",
	},
}

return table.freeze(BreweryStationConfig)
