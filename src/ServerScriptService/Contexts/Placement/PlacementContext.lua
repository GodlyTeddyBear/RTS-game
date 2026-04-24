--!strict

--[[
	Module: PlacementContext
	Purpose: Owns server-authoritative placement requests, placement replication, and run-end cleanup.
	Used In System: Started by Knit on the server; called by Blink remote handlers and other server contexts that need placement state.
	High-Level Flow: Register dependencies -> validate remote payloads -> execute placement command -> hydrate clients and clear at run end.
	Boundaries: Does not own placement rules, spawning, or request shape coercion beyond validation.
]]

-- [Dependencies]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

local BlinkSyncServer = require(ReplicatedStorage.Network.Generated.PlacementSyncServer)
local BlinkRemoteServer = require(ReplicatedStorage.Network.Generated.PlacementRemoteServer)
local PlacementValidator = require(script.Parent.PlacementDomain.Services.PlacementValidator)
local PlaceStructurePolicy = require(script.Parent.PlacementDomain.Policies.PlaceStructurePolicy)
local PlacementService = require(script.Parent.Infrastructure.Services.PlacementService)
local PlacementSyncService = require(script.Parent.Infrastructure.Persistence.PlacementSyncService)
local PlaceStructureCommand = require(script.Parent.Application.Commands.PlaceStructureCommand)
local DestroyStructureInstanceCommand = require(script.Parent.Application.Commands.DestroyStructureInstanceCommand)
local GetPlacedStructuresQuery = require(script.Parent.Application.Queries.GetPlacedStructuresQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type StructureRecord = PlacementTypes.StructureRecord
type PlaceResponse = PlacementTypes.PlaceResponse

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkSyncServer",
		Instance = BlinkSyncServer,
	},
	{
		Name = "BlinkRemoteServer",
		Instance = BlinkRemoteServer,
	},
	{
		Name = "PlacementService",
		Module = PlacementService,
		CacheAs = "_placementService",
	},
	{
		Name = "PlacementSyncService",
		Module = PlacementSyncService,
		CacheAs = "_syncService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "PlacementValidator",
		Module = PlacementValidator,
		CacheAs = "_validator",
	},
	{
		Name = "PlaceStructurePolicy",
		Module = PlaceStructurePolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "PlaceStructureCommand",
		Module = PlaceStructureCommand,
		CacheAs = "_placeStructureCommand",
	},
	{
		Name = "DestroyStructureInstanceCommand",
		Module = DestroyStructureInstanceCommand,
		CacheAs = "_destroyStructureInstanceCommand",
	},
	{
		Name = "GetPlacedStructuresQuery",
		Module = GetPlacedStructuresQuery,
		CacheAs = "_getPlacedStructuresQuery",
	},
}

local PlacementModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

-- [Public API]

--[=[
	@class PlacementContext
	Owns server-authoritative structure placement workflow and sync state.
	@server
]=]
local PlacementContext = Knit.CreateService({
	Name = "PlacementContext",
	Client = {},
	Modules = PlacementModules,
	ExternalServices = {
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
		{ Name = "EconomyContext", CacheAs = "_economyContext" },
	},
	Teardown = {
		Fields = {
			{ Field = "_playerAddedConnection", Method = "Disconnect" },
			{ Field = "_stateChangedConnection", Method = "Disconnect" },
			{ Field = "_syncService", Method = "Destroy" },
			{ Field = "_structurePlacedSignal", Method = "Destroy" },
		},
	},
})

local PlacementBaseContext = BaseContext.new(PlacementContext)

--[=[
	Initializes the placement registry, sync bridge, and request handler.
	@within PlacementContext
]=]
-- Register the placement stack before any remote invocation can reach it.
function PlacementContext:KnitInit()
	PlacementBaseContext:KnitInit()

	self._structurePlacedSignal = Instance.new("BindableEvent")
	self.StructurePlaced = self._structurePlacedSignal.Event
	self._playerAddedConnection = nil :: RBXScriptConnection?
	self._stateChangedConnection = nil :: RBXScriptConnection?

	-- Bind the client placement remote to the request validator and command pipeline.
	BlinkRemoteServer.PlaceStructure.On(function(player: Player, request: any): PlaceResponse
		return self:_HandlePlaceStructureRequest(player, request)
	end)
end

--[=[
	Starts placement hydration and run-end cleanup listeners.
	@within PlacementContext
]=]
-- Hydrate current and future players, then watch for run-end cleanup.
function PlacementContext:KnitStart()
	PlacementBaseContext:KnitStart()

	-- Late joiners need the current placement atom immediately after they connect.
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self._syncService:HydratePlayer(player)
	end)

	-- Existing players must be hydrated before the first placement event can reach them.
	for _, player in Players:GetPlayers() do
		self._syncService:HydratePlayer(player)
	end

	-- RunEnd is the cleanup boundary for all spawned structures and synced records.
	self._stateChangedConnection = self._runContext.StateChanged:Connect(
		function(newState: string, previousState: string)
			local isRunEndCleanup = newState == "RunEnd"
			local isFreshRunStartCleanup = previousState == "Idle" and newState == "Prep"
			if not isRunEndCleanup and not isFreshRunStartCleanup then
				return
			end

			self:_ReleaseOccupiedTilesForCurrentPlacements()
			self._placementService:DestroyAll()
			self._syncService:ClearAll()
		end
	)
end

function PlacementContext:_ReleaseOccupiedTilesForCurrentPlacements()
	local placements = self._syncService:GetPlacementsReadOnly()

	for _, record in ipairs(placements) do
		local occupancyResult = self._worldContext:SetTileOccupied(record.coord, false)
		if occupancyResult.success and occupancyResult.value == true then
			continue
		end

		Result.MentionError("Placement:ReleaseTileOccupancy", "Failed to clear occupied tile at run end", {
			row = record.coord.row,
			col = record.coord.col,
			errorType = occupancyResult.type,
			errorMessage = occupancyResult.message,
			occupancyUpdated = occupancyResult.value,
		}, occupancyResult.type)
	end
end

--[=[
	Validates a placement request and returns a structured placement response.
	@within PlacementContext
	@param player Player -- The calling player.
	@param request any -- The raw Blink payload.
	@return PlaceResponse -- The structured placement response.
]=]
-- Validate the raw remote payload before delegating to the placement command.
function PlacementContext:_HandlePlaceStructureRequest(player: Player, request: any): PlaceResponse
	-- Defensive shape checks keep malformed requests from reaching the command stack.
	local coordRow = type(request) == "table" and request.coord_row or nil
	local coordCol = type(request) == "table" and request.coord_col or nil
	local structureType = type(request) == "table" and request.structureType or nil
	local validatedResult = self._validator:ValidateRequest(coordRow, coordCol, structureType)
	if not validatedResult.success then
		return {
			success = false,
			errorMessage = validatedResult.message,
			instanceId = nil,
		}
	end

	-- Catch keeps structured failures inside the remote response instead of throwing across Blink.
	local placementResult = Catch(function()
		return self._placeStructureCommand:Execute(
			player,
			validatedResult.value.coord,
			validatedResult.value.structureType
		)
	end, "Placement:PlaceStructure")
	if not placementResult.success then
		return {
			success = false,
			errorMessage = placementResult.message,
			instanceId = nil,
		}
	end

	self._structurePlacedSignal:Fire(placementResult.value.record)

	return {
		success = true,
		errorMessage = nil,
		instanceId = placementResult.value.instanceId,
	}
end

--[=[
	Reads the authoritative placement list for other server contexts.
	@within PlacementContext
	@return Result.Result<{ StructureRecord }> -- The cloned placement list.
]=]
-- Expose read-only placement state for other server contexts.
function PlacementContext:GetPlacedStructures(): Result.Result<{ StructureRecord }>
	return Catch(function()
		return Ok(self._getPlacedStructuresQuery:Execute())
	end, "Placement:GetPlacedStructures")
end

--[=[
	Destroys a spawned structure model while leaving placement records untouched.
	@within PlacementContext
	@param instanceId number -- Runtime structure instance id.
	@return Result.Result<boolean> -- Whether the runtime instance destroy path completed.
]=]
function PlacementContext:DestroyStructureInstance(instanceId: number): Result.Result<boolean>
	return Catch(function()
		return self._destroyStructureInstanceCommand:Execute(instanceId)
	end, "Placement:DestroyStructureInstance")
end

function PlacementContext:GetStructureInstance(instanceId: number): Result.Result<Model?>
	return Catch(function()
		return Ok(self._placementService:GetStructureInstance(instanceId))
	end, "Placement:GetStructureInstance")
end

-- [Private Helpers]

--[=[
	Disconnects listeners and tears down the sync bridge.
	@within PlacementContext
]=]
-- Disconnect listeners and tear down the sync bridge when the service shuts down.
function PlacementContext:Destroy()
	local destroyResult = PlacementBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Placement:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return PlacementContext
