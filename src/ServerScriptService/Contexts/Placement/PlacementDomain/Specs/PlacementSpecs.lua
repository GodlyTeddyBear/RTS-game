--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type RunState = RunTypes.RunState
type Tile = WorldTypes.Tile
type ResourceCostMap = { [string]: number }
type SpecialTileRequirementMode = "AtLeastOneTile" | "AllTiles"

--[=[
	@class PlacementSpecs
	Pure predicates for placement business rules.
	@server
]=]
local PlacementSpecs = {}

local ACTIVE_PLACEMENT_STATES: { [RunState]: boolean } = table.freeze({
	Prep = true,
	Wave = true,
	Resolution = true,
	Climax = true,
	Endless = true,
})

-- Placements stay available for the full active run lifecycle, but not lobby or run-end states.
function PlacementSpecs.CanPlaceInRunState(state: RunState): boolean
	return ACTIVE_PLACEMENT_STATES[state] == true
end

-- Config lookup is the authoritative source for whether a structure can be placed at all.
function PlacementSpecs.IsKnownStructureType(structureType: string): boolean
	return PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType] ~= nil
end

-- Occupied tiles can never accept a placement.
function PlacementSpecs.IsTileAvailable(tile: Tile): boolean
	return tile.Occupied == false
end

-- Base disallowed zones are data-driven so map-wide rules stay configurable.
function PlacementSpecs.IsBaseZoneAllowed(tile: Tile): boolean
	return PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[tile.Zone] ~= true
end

-- Placement-prohibited markers always deny structure placement.
function PlacementSpecs.IsNotPlacementProhibited(tile: Tile): boolean
	return tile.IsPlacementProhibited ~= true
end

-- Requirement is data-driven so future structures can opt into resource-tile constraints.
function PlacementSpecs.RequiresResourceTile(structureType: string): boolean
	return PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true
end

-- Resource-gated placements require a side-pocket tile with resource metadata.
function PlacementSpecs.HasRequiredResourceTileData(tile: Tile): boolean
	return tile.Zone == "side_pocket" and tile.ResourceType ~= nil
end

function PlacementSpecs.SatisfiesSpecialTileRequirement(
	tiles: { Tile },
	mode: SpecialTileRequirementMode
): boolean
	if mode == "AllTiles" then
		for _, tile in ipairs(tiles) do
			if not PlacementSpecs.HasRequiredResourceTileData(tile) then
				return false
			end
		end
		return #tiles > 0
	end

	for _, tile in ipairs(tiles) do
		if PlacementSpecs.HasRequiredResourceTileData(tile) then
			return true
		end
	end

	return false
end

-- Capacity is enforced here so commands can fail before any mutation work begins.
function PlacementSpecs.HasCapacity(currentCount: number): boolean
	return currentCount < PlacementConfig.MAX_STRUCTURES
end

function PlacementSpecs.HasValidCostMap(costMap: ResourceCostMap?): boolean
	if type(costMap) ~= "table" then
		return false
	end

	local hasCost = false
	for resourceType, amount in costMap do
		if type(resourceType) ~= "string" or type(amount) ~= "number" then
			return false
		end
		if amount <= 0 or math.floor(amount) ~= amount then
			return false
		end
		hasCost = true
	end

	return hasCost
end

return table.freeze(PlacementSpecs)
