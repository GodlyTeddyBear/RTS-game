--!strict

export type TForgeStation = "FutureForge" | "FutureAssembler" | "FutureReactor"

export type TForgeStationInfo = {
	StructureType: string,
}

local ForgeStationConfig: { [TForgeStation]: TForgeStationInfo } = {
	FutureForge = {
		StructureType = "FutureForge",
	},
	FutureAssembler = {
		StructureType = "FutureAssembler",
	},
	FutureReactor = {
		StructureType = "FutureReactor",
	},
}

return table.freeze(ForgeStationConfig)
