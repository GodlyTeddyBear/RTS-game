--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type RunAtomState = {
	state: RunTypes.RunState,
	waveNumber: number,
	phaseStartedAt: number?,
	phaseEndsAt: number?,
	phaseDuration: number?,
}

type ResourceAtom = EconomyTypes.ResourceAtom
type ResourceWallet = EconomyTypes.ResourceWallet

export type TStructureCardData = {
	structureType: string,
	displayName: string,
	energyCost: number,
	canAfford: boolean,
}

local runAtom: (() -> RunAtomState)? = nil
local resourceAtom: (() -> ResourceAtom)? = nil
local DEFAULT_RUN_STATE: RunAtomState = table.freeze({
	state = "Idle",
	waveNumber = 0,
	phaseStartedAt = nil,
	phaseEndsAt = nil,
	phaseDuration = nil,
})
local DEFAULT_RESOURCE_STATE: ResourceAtom = table.freeze({})

local function _GetRunAtom(): () -> RunAtomState
	if runAtom == nil then
		local runController = Knit.GetController("RunController")
		runAtom = runController:GetAtom()
	end
	return runAtom
end

local function _GetResourceAtom(): () -> ResourceAtom
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end
	return resourceAtom
end

local function _FormatStructureName(structureType: string): string
	local head = string.sub(structureType, 1, 1)
	if head == "" then
		return structureType
	end
	return string.upper(head) .. string.sub(structureType, 2)
end

local function usePlacementPaletteHud(): { isVisible: boolean, structures: { TStructureCardData } }
	local runState = ReactCharm.useAtom(_GetRunAtom()) or DEFAULT_RUN_STATE
	local wallets = ReactCharm.useAtom(_GetResourceAtom()) or DEFAULT_RESOURCE_STATE

	local energy = 0
	local wallet: ResourceWallet? = wallets[Players.LocalPlayer.UserId]
	if wallet then
		energy = wallet.energy
	end

	local structures = table.create(1)
	for structureType, energyCost in PlacementConfig.STRUCTURE_PLACEMENT_COSTS do
		structures[#structures + 1] = table.freeze({
			structureType = structureType,
			displayName = _FormatStructureName(structureType),
			energyCost = energyCost,
			canAfford = energy >= energyCost,
		} :: TStructureCardData)
	end

	return table.freeze({
		isVisible = runState.state == "Prep",
		structures = table.freeze(structures),
	})
end

return usePlacementPaletteHud
