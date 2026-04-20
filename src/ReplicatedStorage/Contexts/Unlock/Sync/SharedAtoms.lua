--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

--- Server stores all players' unlock state, indexed by UserId
export type TPlayerUnlocks = {
	[number]: TUnlockState,
}

--- Creates server-side atom for all players' unlock state
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerUnlocks)
end

--- Creates client-side atom for current player's unlock state only
local function CreateClientAtom()
	return Charm.atom(nil :: TUnlockState?)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
