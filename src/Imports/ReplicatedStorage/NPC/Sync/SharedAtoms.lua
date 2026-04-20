--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local FlagTypes = require(ReplicatedStorage.Contexts.NPC.Types.FlagTypes)

-- Server atom: stores all players' flags indexed by userId
-- { [userId]: TPlayerFlags }
export type TAllPlayerFlags = {
	[number]: FlagTypes.TPlayerFlags,
}

-- Client atom: stores only current player's flags
-- { [flagName]: TFlagValue }
export type TClientFlags = FlagTypes.TPlayerFlags

local function CreateServerAtom()
	return Charm.atom({} :: TAllPlayerFlags)
end

local function CreateClientAtom()
	return Charm.atom({} :: TClientFlags)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
