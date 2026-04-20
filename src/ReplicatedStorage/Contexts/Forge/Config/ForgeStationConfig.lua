--!strict

export type TForgeStation = "Anvil" | "WorkBench"

export type TForgeStationInfo = {
	BuildingType: string,
	BuildingUnlockId: string,
}

local ForgeStationConfig: { [TForgeStation]: TForgeStationInfo } = {
	Anvil = {
		BuildingType = "Anvil",
		BuildingUnlockId = "Forge_Anvil",
	},
	WorkBench = {
		BuildingType = "WorkBench",
		BuildingUnlockId = "Forge_WorkBench",
	},
}

return table.freeze(ForgeStationConfig)
