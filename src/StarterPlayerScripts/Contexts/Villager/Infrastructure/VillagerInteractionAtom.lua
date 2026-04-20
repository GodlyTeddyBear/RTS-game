--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type TVillagerInteractionState = {
	open: boolean,
	villagerId: string?,
	offerId: string?,
	villagerName: string?,
}

local villagerInteractionAtom = Charm.atom({
	open = false,
	villagerId = nil,
	offerId = nil,
	villagerName = nil,
} :: TVillagerInteractionState)

local function openVillagerOffer(villagerId: string, offerId: string, villagerName: string)
	villagerInteractionAtom(function(_: TVillagerInteractionState): TVillagerInteractionState
		return {
			open = true,
			villagerId = villagerId,
			offerId = offerId,
			villagerName = villagerName,
		}
	end)
end

local function closeVillagerOffer()
	villagerInteractionAtom(function(_: TVillagerInteractionState): TVillagerInteractionState
		return {
			open = false,
			villagerId = nil,
			offerId = nil,
			villagerName = nil,
		}
	end)
end

return {
	Atom = villagerInteractionAtom,
	Open = openVillagerOffer,
	Close = closeVillagerOffer,
}
