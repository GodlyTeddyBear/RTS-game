--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementSpecs = require(script.Parent.Parent.Specs.PlacementSpecs)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

type GridCoord = PlacementTypes.GridCoord
type Tile = WorldTypes.Tile

export type PlacementDecision = {
	tile: Tile,
	cost: number,
}

--[=[
	@class PlaceStructurePolicy
	Resolves read dependencies and evaluates placement specs.
	@server
]=]
local PlaceStructurePolicy = {}
PlaceStructurePolicy.__index = PlaceStructurePolicy

--[=[
	Creates a new placement policy wrapper.
	@within PlaceStructurePolicy
	@return PlaceStructurePolicy -- The new policy instance.
]=]
-- The policy is stateless; the registry wires live dependencies during Init.
function PlaceStructurePolicy.new()
	return setmetatable({}, PlaceStructurePolicy)
end

--[=[
	Resolves the live read dependencies for placement evaluation.
	@within PlaceStructurePolicy
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
-- Cache read-only collaborators once so the command can reuse a single policy instance.
function PlaceStructurePolicy:Init(registry: any, _name: string)
	self._syncService = registry:Get("PlacementSyncService")
end

function PlaceStructurePolicy:Start(registry: any, _name: string)
	self._runContext = registry:Get("RunContext")
	self._worldContext = registry:Get("WorldContext")
end

--[=[
	Checks all placement preconditions and returns the live tile and cost.
	@within PlaceStructurePolicy
	@param coord GridCoord -- The requested grid coordinate.
	@param structureType string -- The placement key.
	@return Result.Result<PlacementDecision> -- The resolved placement decision.
]=]
-- Resolve every required read before the command performs any mutation.
function PlaceStructurePolicy:Check(coord: GridCoord, structureType: string): Result.Result<PlacementDecision>
	-- Run state gates the whole feature, so it is the first live lookup.
	local runState = Try(self._runContext:GetState())
	Ensure(PlacementSpecs.IsPrepState(runState), "NotPrepState", Errors.NOT_PREP_STATE, {
		state = runState,
	})

	Ensure(PlacementSpecs.IsKnownStructureType(structureType), "UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE, {
		structureType = structureType,
	})

	-- TODO: Inject Structure/Crafting unlock provider and enforce unlock status here.

	-- Tile lookup happens before occupancy checks because the world context owns bounds validation.
	local tile = Try(self._worldContext:GetTile(coord))
	Ensure(tile ~= nil, "InvalidCoord", Errors.INVALID_COORD, {
		row = coord.row,
		col = coord.col,
	})

	local resolvedTile = tile :: Tile

	Ensure(PlacementSpecs.IsTileAvailable(resolvedTile), "TileUnavailable", Errors.TILE_UNAVAILABLE, {
		row = coord.row,
		col = coord.col,
		zone = resolvedTile.zone,
		occupied = resolvedTile.occupied,
	})

	Ensure(PlacementSpecs.IsZoneCompatible(structureType, resolvedTile), "IncompatibleTileZone", Errors.INCOMPATIBLE_TILE_ZONE, {
		structureType = structureType,
		zone = resolvedTile.zone,
	})

	if PlacementSpecs.RequiresResourceTile(structureType) then
		Ensure(PlacementSpecs.HasRequiredResourceTileData(resolvedTile), "ResourceTileRequired", Errors.RESOURCE_TILE_REQUIRED, {
			structureType = structureType,
			zone = resolvedTile.zone,
		})
	end

	-- Capacity is read from the placement atom so the command never overshoots the run cap.
	local currentCount = self._syncService:GetPlacementCount()
	Ensure(PlacementSpecs.HasCapacity(currentCount), "MaxStructuresReached", Errors.MAX_STRUCTURES_REACHED, {
		currentCount = currentCount,
		maxStructures = PlacementConfig.MAX_STRUCTURES,
	})

	local cost = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]
	Ensure(cost ~= nil, "UnknownStructureType", Errors.UNKNOWN_STRUCTURE_TYPE, {
		structureType = structureType,
	})

	return Ok({
		tile = resolvedTile,
		cost = cost :: number,
	})
end

return PlaceStructurePolicy
