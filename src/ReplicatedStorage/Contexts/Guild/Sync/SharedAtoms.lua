--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local AdventurerTypes = require(ReplicatedStorage.Contexts.Guild.Types.AdventurerTypes)

type TAdventurer = AdventurerTypes.TAdventurer

--- Server stores all players' adventurers, indexed by UserId
export type TPlayerAdventurers = {
	[number]: { [string]: TAdventurer },
}

--- Creates server-side atom for all players' adventurers
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerAdventurers)
end

--- Creates client-side atom for current player's adventurers only
local function CreateClientAtom()
	return Charm.atom({} :: { [string]: TAdventurer })
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
