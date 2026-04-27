--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type ResourceClientState = EconomyTypes.ResourceClientState

local resourceAtom: (() -> ResourceClientState)? = nil

local function _GetResourceAtom(): () -> ResourceClientState
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end

	return resourceAtom
end

local function useInventoryResources(): ResourceClientState
	return ReactCharm.useAtom(_GetResourceAtom()) :: ResourceClientState
end

return useInventoryResources
