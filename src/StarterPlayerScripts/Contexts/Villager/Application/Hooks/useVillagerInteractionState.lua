--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local VillagerInteractionAtom = require(script.Parent.Parent.Parent.Infrastructure.VillagerInteractionAtom)

local useAtom = ReactCharm.useAtom

local function useVillagerInteractionState()
	return useAtom(VillagerInteractionAtom.Atom)
end

return useVillagerInteractionState
