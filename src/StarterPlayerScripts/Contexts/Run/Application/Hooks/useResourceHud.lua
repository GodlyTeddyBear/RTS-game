--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local ResourceHudViewModel = require(script.Parent.Parent.ViewModels.ResourceHudViewModel)

type ResourceClientState = EconomyTypes.ResourceClientState

export type TResourceHudData = {
	energy: number,
	metal: number,
	crystal: number,
	isSyncing: boolean,
}

local resourceAtom: (() -> ResourceClientState)? = nil

local function _GetResourceAtom(): () -> ResourceClientState
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end
	return resourceAtom
end

local function useResourceHud(): TResourceHudData
	local wallet = ReactCharm.useAtom(_GetResourceAtom()) :: ResourceClientState
	return ResourceHudViewModel.fromWallet(wallet)
end

return useResourceHud
