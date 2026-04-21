--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type ResourceWallet = EconomyTypes.ResourceWallet

export type TResourceHudData = {
	energy: number,
	metal: number,
	crystal: number,
	isSyncing: boolean,
}

local DEFAULT_RESOURCE_HUD: TResourceHudData = table.freeze({
	energy = 0,
	metal = 0,
	crystal = 0,
	isSyncing = true,
})

local ResourceHudViewModel = {}

function ResourceHudViewModel.getEnergy(wallet: ResourceWallet?): number
	if wallet == nil then
		return 0
	end

	return wallet.energy
end

function ResourceHudViewModel.fromWallet(wallet: ResourceWallet?): TResourceHudData
	if wallet == nil then
		return DEFAULT_RESOURCE_HUD
	end

	local resources = wallet.resources
	return table.freeze({
		energy = wallet.energy,
		metal = resources.Metal or 0,
		crystal = resources.Crystal or 0,
		isSyncing = false,
	} :: TResourceHudData)
end

return table.freeze(ResourceHudViewModel)
