--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

--- Per-slot building data
export type TBuildingSlot = {
	BuildingType: string,
	Level: number,
}

--- Zone name → slot index → building data
export type TZoneSlots = { [number]: TBuildingSlot }

--- All buildings for a player: zone name → zone slots
export type TBuildingsMap = { [string]: TZoneSlots }

--- Server atom: all players indexed by UserId
local function CreateServerAtom()
	return Charm.atom({} :: { [number]: TBuildingsMap })
end

--- Client atom: current player's buildings only
local function CreateClientAtom()
	return Charm.atom({} :: TBuildingsMap)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
