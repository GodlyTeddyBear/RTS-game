--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type RunState = RunTypes.RunState
type Tile = WorldTypes.Tile

--[=[
	@class PlacementSpecs
	Pure predicates for placement business rules.
	@server
]=]
local PlacementSpecs = {}

-- Prep is the only state that allows new placements.
function PlacementSpecs.IsPrepState(state: RunState): boolean
	return state == "Prep"
end

-- Config lookup is the authoritative source for whether a structure can be placed at all.
function PlacementSpecs.IsKnownStructureType(structureType: string): boolean
	return PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType] ~= nil
end

-- Occupied tiles can never accept a placement.
function PlacementSpecs.IsTileAvailable(tile: Tile): boolean
	return tile.occupied == false
end

-- Base disallowed zones are data-driven so map-wide rules stay configurable.
function PlacementSpecs.IsBaseZoneAllowed(tile: Tile): boolean
	return PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[tile.zone] ~= true
end

-- Placement-prohibited markers always deny structure placement.
function PlacementSpecs.IsNotPlacementProhibited(tile: Tile): boolean
	return tile.isPlacementProhibited ~= true
end

-- Requirement is data-driven so future structures can opt into resource-tile constraints.
function PlacementSpecs.RequiresResourceTile(structureType: string): boolean
	return PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true
end

-- Resource-gated placements require a side-pocket tile with resource metadata.
function PlacementSpecs.HasRequiredResourceTileData(tile: Tile): boolean
	return tile.zone == "side_pocket" and tile.resourceType ~= nil
end

-- Capacity is enforced here so commands can fail before any mutation work begins.
function PlacementSpecs.HasCapacity(currentCount: number): boolean
	return currentCount < PlacementConfig.MAX_STRUCTURES
end

return table.freeze(PlacementSpecs)
