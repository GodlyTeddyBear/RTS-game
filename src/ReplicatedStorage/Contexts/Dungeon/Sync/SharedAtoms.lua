--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local DungeonTypes = require(ReplicatedStorage.Contexts.Dungeon.Types.DungeonTypes)

type TDungeonState = DungeonTypes.TDungeonState

--- Server stores all players' dungeon states, indexed by UserId
export type TPlayerDungeonStates = {
	[number]: TDungeonState,
}

--- Creates server-side atom for all players' dungeon states
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerDungeonStates)
end

--- Creates client-side atom for the current player's dungeon state only
local function CreateClientAtom()
	return Charm.atom(nil :: TDungeonState?)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
