--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

--- Server stores all players' gold, indexed by UserId
export type TPlayerGold = {
	[number]: number,
}

--- Creates server-side atom for all players' gold
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerGold)
end

--- Creates client-side atom for current player's gold only
local function CreateClientAtom()
	return Charm.atom(0 :: number)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
