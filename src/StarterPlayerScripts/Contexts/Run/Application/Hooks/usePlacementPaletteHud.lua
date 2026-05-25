--!strict

--[[
	Module: usePlacementPaletteHud
	Purpose: Builds the client placement palette visibility state and structure card data.
	Used In System: Read by the placement palette UI on the client when rendering the build menu.
	High-Level Flow: Read run and resource atoms -> derive affordability -> emit frozen card data for the UI.
	Boundaries: Owns presentation data only; does not own placement rules, pricing tables, or input handling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local CanPlaceInRunState = require(script.Parent.Parent.Parent.Parent.Placement.Application.CanPlaceInRunState)
local ResourceHudViewModel = require(script.Parent.Parent.ViewModels.ResourceHudViewModel)

-- [Types]

type RunAtomState = {
	State: RunTypes.RunState,
	WaveNumber: number,
	PhaseStartedAt: number?,
	PhaseEndsAt: number?,
	PhaseDuration: number?,
}

type ResourceClientState = EconomyTypes.ResourceClientState
type ResourceCostMap = EconomyTypes.ResourceCostMap

--[=[
	@interface TStructureCardData
	@within usePlacementPaletteHud
	.structureType string -- Canonical structure key used by placement and selection.
	.displayName string -- Human-readable label shown on the card.
	.costMap ResourceCostMap -- Resources required to place the structure.
	.costText string -- Compact resource cost label.
	.canAfford boolean -- Whether the current wallet can buy the structure.
]=]
export type TStructureCardData = {
	structureType: string,
	displayName: string,
	costMap: ResourceCostMap,
	costText: string,
	canAfford: boolean,
	layoutOrder: number,
}

local runAtom: (() -> RunAtomState)? = nil
local resourceAtom: (() -> ResourceClientState)? = nil
local DEFAULT_RUN_STATE: RunAtomState = table.freeze({
	State = "Idle",
	WaveNumber = 0,
	PhaseStartedAt = nil,
	PhaseEndsAt = nil,
	PhaseDuration = nil,
})
local STRUCTURE_DISPLAY_ORDER = table.freeze({
	"SentryTurret",
	"Extractor",
	"StasisField",
	"ArcPylon",
	"BulwarkProjector",
	"RelayBeacon",
})

-- [Private Helpers]

-- Lazily resolves the run atom so the hook can stay controller-agnostic.
local function _GetRunAtom(): () -> RunAtomState
	if runAtom == nil then
		local runController = Knit.GetController("RunController")
		runAtom = runController:GetAtom()
	end
	return runAtom
end

-- Lazily resolves the resource atom so the hook can read economy state without extra controller lookups.
local function _GetResourceAtom(): () -> ResourceClientState
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end
	return resourceAtom
end

-- Formats a placement key into a readable label for the palette cards.
local function _FormatStructureName(structureType: string): string
	local structureDefinition = StructureConfig.STRUCTURES[structureType]
	if structureDefinition ~= nil and type(structureDefinition.DisplayName) == "string" and structureDefinition.DisplayName ~= "" then
		return structureDefinition.DisplayName
	end

	local head = string.sub(structureType, 1, 1)
	if head == "" then
		return structureType
	end
	return string.upper(head) .. string.sub(structureType, 2)
end

local function _GetBalance(wallet: ResourceClientState, resourceType: string): number
	if wallet == nil then
		return 0
	end

	if resourceType == "Energy" then
		return ResourceHudViewModel.getEnergy(wallet)
	end

	local resources = wallet.Resources
	if resources == nil then
		return 0
	end

	return resources[resourceType] or 0
end

local function _CanAfford(wallet: ResourceClientState, costMap: ResourceCostMap): boolean
	for resourceType, amount in costMap do
		if _GetBalance(wallet, resourceType) < amount then
			return false
		end
	end

	return true
end

local function _FormatResourceLabel(resourceType: string): string
	if resourceType == "Energy" then
		return "E"
	end
	if resourceType == "Metal" then
		return "M"
	end
	if resourceType == "Crystal" then
		return "C"
	end
	return string.sub(resourceType, 1, 1)
end

local function _FormatCostText(costMap: ResourceCostMap): string
	local parts = {}
	local order = { "Energy", "Metal", "Crystal" }
	local included = {}

	for _, resourceType in ipairs(order) do
		local amount = costMap[resourceType]
		if amount ~= nil then
			table.insert(parts, string.format("%d %s", amount, _FormatResourceLabel(resourceType)))
			included[resourceType] = true
		end
	end

	for resourceType, amount in costMap do
		if included[resourceType] ~= true then
			table.insert(parts, string.format("%d %s", amount, _FormatResourceLabel(resourceType)))
		end
	end

	return table.concat(parts, " / ")
end

local function _BuildOrderedStructureTypes(): { string }
	local orderedTypes = {}
	local included = {}

	for index, structureType in ipairs(STRUCTURE_DISPLAY_ORDER) do
		if PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType] ~= nil then
			orderedTypes[index] = structureType
			included[structureType] = true
		end
	end

	for structureType in PlacementConfig.STRUCTURE_PLACEMENT_COSTS do
		if included[structureType] ~= true then
			orderedTypes[#orderedTypes + 1] = structureType
		end
	end

	return orderedTypes
end

-- [Public API]

--[=[
	@class usePlacementPaletteHud
	Returns the placement palette visibility state and structure card metadata for the client UI.
	@client
]=]
--[=[
	Returns the placement palette visibility state and immutable structure card metadata.
	@within usePlacementPaletteHud
	@return { isVisible: boolean, structures: { TStructureCardData } } -- Palette visibility and structure cards.
]=]
local function usePlacementPaletteHud(): { isVisible: boolean, structures: { TStructureCardData } }
	local runState = ReactCharm.useAtom(_GetRunAtom()) or DEFAULT_RUN_STATE
	local wallet = ReactCharm.useAtom(_GetResourceAtom()) :: ResourceClientState

	local orderedStructureTypes = _BuildOrderedStructureTypes()
	local structures = table.create(#orderedStructureTypes)
	for index, structureType in ipairs(orderedStructureTypes) do
		local costMap = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]
		structures[#structures + 1] = table.freeze({
			structureType = structureType,
			displayName = _FormatStructureName(structureType),
			costMap = costMap,
			costText = _FormatCostText(costMap),
			canAfford = _CanAfford(wallet, costMap),
			layoutOrder = index,
		} :: TStructureCardData)
	end

	return table.freeze({
		isVisible = CanPlaceInRunState(runState.State),
		structures = table.freeze(structures),
	})
end

return usePlacementPaletteHud
