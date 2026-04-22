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
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
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

--[=[
	@class WorldContext
	Exposes authoritative world layout queries and tile occupancy controls for server contexts.
	@server
]=]
local WorldContext = Knit.CreateService({
	Name = "WorldContext",
	Client = {},
})

local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure
type GridCoord = WorldTypes.GridCoord
type Tile = WorldTypes.Tile

-- [Initialization]

--[=[
	Initializes the world services, builds the tile grid, and caches query wrappers.
	@within WorldContext
]=]
function WorldContext:KnitInit()
	-- Register infrastructure services so the world grid is built before any query can run.
	local registry = Registry.new("Server")
	registry:Register("WorldGridRuntimeService", WorldGridRuntimeService.new(), "Infrastructure")
	registry:Register("WorldGridService", WorldGridService.new(), "Infrastructure")
	registry:Register("WorldLayoutService", WorldLayoutService.new(), "Infrastructure")
	registry:InitAll()

	-- Cache the concrete services after initialization so query objects can stay thin.
	self._worldGridService = registry:Get("WorldGridService")
	self._worldLayoutService = registry:Get("WorldLayoutService")

	-- Build one query object per world read path to keep the context methods pass-through.
	self._queries = {
		GetTile = GetTileQuery.new(self._worldGridService),
		GetSpawnPoints = GetSpawnPointsQuery.new(self._worldLayoutService),
		GetGoalPoint = GetGoalPointQuery.new(self._worldLayoutService),
		GetBuildableTiles = GetBuildableTilesQuery.new(self._worldGridService),
		GetExtractionTiles = GetExtractionTilesQuery.new(self._worldGridService),
		GetLaneTiles = GetLaneTilesQuery.new(self._worldGridService),
	}

	-- Emit a milestone so startup order is visible in the log stream.
	Result.MentionSuccess("World:KnitInit", "World context initialized", nil)
end

-- [Public API]

--[=[
	Starts the world context after Knit initialization.
	@within WorldContext
]=]
function WorldContext:KnitStart()
	Result.MentionEvent("World:KnitStart", "World context started", nil)
end

--[=[
	Returns the tile at a grid coordinate, or nil when the coordinate is invalid or out of bounds.
	@within WorldContext
	@param coord GridCoord -- Grid coordinate to resolve.
	@return Result.Result<Tile?> -- The resolved tile wrapped in `Result`.
]=]
function WorldContext:GetTile(coord: GridCoord): Result.Result<Tile?>
	return Catch(function()
		Ensure(coord, "InvalidCoord", Errors.INVALID_COORD)
		return Ok(self._queries.GetTile:Execute(coord))
	end, "World:GetTile")
end

--[=[
	Returns all configured spawn points for enemy wave entry.
	@within WorldContext
	@return Result.Result<{ CFrame }> -- Spawn points wrapped in `Result`.
]=]
function WorldContext:GetSpawnPoints(): Result.Result<{ CFrame }>
	return Catch(function()
		return Ok(self._queries.GetSpawnPoints:Execute())
	end, "World:GetSpawnPoints")
end

--[=[
	Returns the goal point that enemies path toward.
	@within WorldContext
	@return Result.Result<CFrame?> -- Goal point wrapped in `Result`.
]=]
function WorldContext:GetGoalPoint(): Result.Result<CFrame?>
	return Catch(function()
		return Ok(self._queries.GetGoalPoint:Execute())
	end, "World:GetGoalPoint")
end

--[=[
	Returns all currently buildable tiles that are not blocked or occupied.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Buildable tile list wrapped in `Result`.
]=]
function WorldContext:GetBuildableTiles(): Result.Result<{ Tile }>
	return Catch(function()
		return Ok(self._queries.GetBuildableTiles:Execute())
	end, "World:GetBuildableTiles")
end

--[=[
	Returns all extraction tiles that carry a resource type.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Extraction tile list wrapped in `Result`.
]=]
function WorldContext:GetExtractionTiles(): Result.Result<{ Tile }>
	return Catch(function()
		return Ok(self._queries.GetExtractionTiles:Execute())
	end, "World:GetExtractionTiles")
end

--[=[
	Returns all lane tiles used for enemy path construction.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Lane tile list wrapped in `Result`.
]=]
function WorldContext:GetLaneTiles(): Result.Result<{ Tile }>
	return Catch(function()
		return Ok(self._queries.GetLaneTiles:Execute())
	end, "World:GetLaneTiles")
end

--[=[
	Returns buildable tiles under the older placement-zone name.
	@within WorldContext
	@return Result.Result<{ Tile }> -- Buildable tile list wrapped in `Result`.
]=]
function WorldContext:GetPlacementZones(): Result.Result<{ Tile }>
	return self:GetBuildableTiles()
end

--[=[
	Toggles tile occupancy for server-side placement and reservation logic.
	@within WorldContext
	@param coord GridCoord -- Grid coordinate to update.
	@param occupied boolean -- Whether the tile should be marked occupied.
	@return Result.Result<boolean> -- Whether the tile was found and updated, wrapped in `Result`.
]=]
function WorldContext:SetTileOccupied(coord: GridCoord, occupied: boolean): Result.Result<boolean>
	return Catch(function()
		Ensure(coord, "InvalidCoord", Errors.INVALID_COORD)
		return Ok(self._worldGridService:SetOccupied(coord, occupied))
	end, "World:SetTileOccupied")
end

WrapContext(WorldContext, "World")

return WorldContext
