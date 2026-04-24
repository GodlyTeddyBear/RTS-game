--!strict

--[[
    Module: WorldContext
    Purpose: Owns the server bridge for authoritative world queries and tile occupancy updates.
    Used In System: Called by other server contexts that need world layout, spawn, goal, or occupancy data.
    High-Level Flow: Initialize grid services -> cache query adapters -> expose Result-wrapped context methods.
    Boundaries: Owns orchestration only; does not own grid math, layout derivation, or placement policy decisions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

local WorldGridRuntimeService = require(script.Parent.Infrastructure.Services.WorldGridRuntimeService)
local WorldGridService = require(script.Parent.Infrastructure.Services.WorldGridService)
local WorldLayoutService = require(script.Parent.Infrastructure.Services.WorldLayoutService)
local Errors = require(script.Parent.Errors)

local GetTileQuery = require(script.Parent.Application.Queries.GetTileQuery)
local GetSpawnPointsQuery = require(script.Parent.Application.Queries.GetSpawnPointsQuery)
local GetGoalPointQuery = require(script.Parent.Application.Queries.GetGoalPointQuery)
local GetBuildableTilesQuery = require(script.Parent.Application.Queries.GetBuildableTilesQuery)
local GetExtractionTilesQuery = require(script.Parent.Application.Queries.GetExtractionTilesQuery)
local GetLaneTilesQuery = require(script.Parent.Application.Queries.GetLaneTilesQuery)

-- [Dependencies]

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "WorldGridRuntimeService",
		Module = WorldGridRuntimeService,
	},
	{
		Name = "WorldGridService",
		Module = WorldGridService,
		CacheAs = "_worldGridService",
	},
	{
		Name = "WorldLayoutService",
		Module = WorldLayoutService,
		CacheAs = "_worldLayoutService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "GetTileQuery",
		Factory = function(_service: any, baseContext: any)
			return GetTileQuery.new(baseContext:GetRegistry():Get("WorldGridService"))
		end,
		CacheAs = "_getTileQuery",
	},
	{
		Name = "GetSpawnPointsQuery",
		Factory = function(_service: any, baseContext: any)
			return GetSpawnPointsQuery.new(baseContext:GetRegistry():Get("WorldLayoutService"))
		end,
		CacheAs = "_getSpawnPointsQuery",
	},
	{
		Name = "GetGoalPointQuery",
		Factory = function(_service: any, baseContext: any)
			return GetGoalPointQuery.new(baseContext:GetRegistry():Get("WorldLayoutService"))
		end,
		CacheAs = "_getGoalPointQuery",
	},
	{
		Name = "GetBuildableTilesQuery",
		Factory = function(_service: any, baseContext: any)
			return GetBuildableTilesQuery.new(baseContext:GetRegistry():Get("WorldGridService"))
		end,
		CacheAs = "_getBuildableTilesQuery",
	},
	{
		Name = "GetExtractionTilesQuery",
		Factory = function(_service: any, baseContext: any)
			return GetExtractionTilesQuery.new(baseContext:GetRegistry():Get("WorldGridService"))
		end,
		CacheAs = "_getExtractionTilesQuery",
	},
	{
		Name = "GetLaneTilesQuery",
		Factory = function(_service: any, baseContext: any)
			return GetLaneTilesQuery.new(baseContext:GetRegistry():Get("WorldGridService"))
		end,
		CacheAs = "_getLaneTilesQuery",
	},
}

local WorldModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

--[=[
	@class WorldContext
	Exposes authoritative world layout queries and tile occupancy controls for server contexts.
	@server
]=]
local WorldContext = Knit.CreateService({
	Name = "WorldContext",
	Client = {},
	Modules = WorldModules,
	ExternalServices = {
		{ Name = "MapContext", CacheAs = "_mapContext" },
	},
})

local WorldBaseContext = BaseContext.new(WorldContext)
local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure
type GridCoord = WorldTypes.GridCoord
type Tile = WorldTypes.Tile
type WorldContextService = typeof(WorldContext) & {
	_getTileQuery: any,
	_getSpawnPointsQuery: any,
	_getGoalPointQuery: any,
	_getBuildableTilesQuery: any,
	_getExtractionTilesQuery: any,
	_getLaneTilesQuery: any,
	_worldGridService: any,
	_mapContext: any,
}

-- [Initialization]

--[=[
	Initializes the world services, builds the tile grid, and caches query wrappers.
	@within WorldContext
]=]
function WorldContext:KnitInit()
	WorldBaseContext:KnitInit()
	Result.MentionSuccess("World:KnitInit", "World context initialized", nil)
end

-- [Public API]

--[=[
	Starts the world context after Knit initialization.
	@within WorldContext
]=]
function WorldContext:KnitStart()
	WorldBaseContext:KnitStart()
	Result.MentionEvent("World:KnitStart", "World context started", nil)
end

--[=[
	Returns the tile at a grid coordinate, or nil when the coordinate is invalid or out of bounds.
	@within WorldContext
	@param coord GridCoord -- Grid coordinate to resolve.
	@return Result.Result<Tile?> -- The resolved tile wrapped in `Result`.
]=]
function WorldContext.GetTile(self: WorldContextService, coord: GridCoord): Result.Result<Tile?>
	return Catch(function()
		Ensure(coord, "InvalidCoord", Errors.INVALID_COORD)
		return Ok(self._getTileQuery:Execute(coord))
	end, "World:GetTile")
end

--[=[
	Returns all configured spawn points for enemy wave entry.
	@within WorldContext
	@return Result.Result<{ CFrame }> -- Spawn points wrapped in `Result`.
]=]
function WorldContext.GetSpawnPoints(self: WorldContextService): Result.Result<{ CFrame }>
	return Catch(function()
		return Ok(self._getSpawnPointsQuery:Execute())
	end, "World:GetSpawnPoints")
end

--[=[
	Returns the goal point that enemies path toward.
	@within WorldContext
	@return Result.Result<CFrame?> -- Goal point wrapped in `Result`.
]=]
function WorldContext.GetGoalPoint(self: WorldContextService): Result.Result<CFrame?>
	return Catch(function()
		return Ok(self._getGoalPointQuery:Execute())
	end, "World:GetGoalPoint")
end

--[=[
	Returns all currently buildable tiles that are not blocked or occupied.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Buildable tile list wrapped in `Result`.
]=]
function WorldContext.GetBuildableTiles(self: WorldContextService): Result.Result<{ Tile }>
	return Catch(function()
		return Ok(self._getBuildableTilesQuery:Execute())
	end, "World:GetBuildableTiles")
end

--[=[
	Returns all extraction tiles that carry a resource type.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Extraction tile list wrapped in `Result`.
]=]
function WorldContext.GetExtractionTiles(self: WorldContextService): Result.Result<{ Tile }>
	return Catch(function()
		return Ok(self._getExtractionTilesQuery:Execute())
	end, "World:GetExtractionTiles")
end

--[=[
	Returns all lane tiles used for enemy path construction.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Lane tile list wrapped in `Result`.
]=]
function WorldContext.GetLaneTiles(self: WorldContextService): Result.Result<{ Tile }>
	return Catch(function()
		return Ok(self._getLaneTilesQuery:Execute())
	end, "World:GetLaneTiles")
end

--[=[
	Returns buildable tiles under the older placement-zone name.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Buildable tile list wrapped in `Result`.
]=]
function WorldContext.GetPlacementZones(self: WorldContextService): Result.Result<{ Tile }>
	return self:GetBuildableTiles()
end

--[=[
	Toggles tile occupancy for server-side placement and reservation logic.
	@within WorldContext
	@param coord GridCoord -- Grid coordinate to update.
	@param occupied boolean -- Whether the tile should be marked occupied.
	@return Result.Result<boolean> -- Whether the tile was found and updated, wrapped in `Result`.
]=]
function WorldContext.SetTileOccupied(
	self: WorldContextService,
	coord: GridCoord,
	occupied: boolean
): Result.Result<boolean>
	return Catch(function()
		Ensure(coord, "InvalidCoord", Errors.INVALID_COORD)
		return Ok(self._worldGridService:SetOccupied(coord, occupied))
	end, "World:SetTileOccupied")
end

--[=[
	Invalidates cached runtime world geometry and forces rebuild against the active runtime map.
	@within WorldContext
	@return Result.Result<boolean> -- True when runtime geometry was refreshed successfully.
]=]
function WorldContext.RefreshRuntimeGeometry(self: WorldContextService): Result.Result<boolean>
	return Catch(function()
		self._worldGridService:ResetCache()
		self._worldGridService:Build()
		return Ok(true)
	end, "World:RefreshRuntimeGeometry")
end

return WorldContext
