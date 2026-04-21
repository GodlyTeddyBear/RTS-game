--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type ResourceAtom = EconomyTypes.ResourceAtom
type ResourceWallet = EconomyTypes.ResourceWallet

export type TResourceHudData = {
	energy: number,
	metal: number,
	crystal: number,
}

local DEFAULT_RESOURCE_HUD: TResourceHudData = table.freeze({
	energy = 0,
	metal = 0,
	crystal = 0,
})

local resourceAtom: (() -> ResourceAtom)? = nil

local function _GetResourceAtom(): () -> ResourceAtom
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end
	return resourceAtom
end

local function _ToHudData(wallet: ResourceWallet?): TResourceHudData
	if wallet == nil then
		return DEFAULT_RESOURCE_HUD
	end

	local resources = wallet.resources
	return {
		energy = wallet.energy,
		metal = resources.Metal or 0,
		crystal = resources.Crystal or 0,
	}
end

local function useResourceHud(): TResourceHudData
	local wallets = ReactCharm.useAtom(_GetResourceAtom())
	local playerWallet = wallets[Players.LocalPlayer.UserId]
	return _ToHudData(playerWallet)
end

return useResourceHud
