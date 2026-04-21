--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

local BlinkSyncServer = require(ReplicatedStorage.Network.Generated.PlacementSyncServer)
local BlinkRemoteServer = require(ReplicatedStorage.Network.Generated.PlacementRemoteServer)
local PlacementValidator = require(script.Parent.PlacementDomain.Services.PlacementValidator)
local PlaceStructurePolicy = require(script.Parent.PlacementDomain.Policies.PlaceStructurePolicy)
local PlacementService = require(script.Parent.Infrastructure.Services.PlacementService)
local PlacementSyncService = require(script.Parent.Infrastructure.Persistence.PlacementSyncService)
local PlaceStructureCommand = require(script.Parent.Application.Commands.PlaceStructureCommand)
local GetPlacedStructuresQuery = require(script.Parent.Application.Queries.GetPlacedStructuresQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type StructureRecord = PlacementTypes.StructureRecord
type PlaceResponse = PlacementTypes.PlaceResponse

--[=[
	@class PlacementContext
	Owns server-authoritative structure placement workflow and sync state.
	@server
]=]
local PlacementContext = Knit.CreateService({
	Name = "PlacementContext",
	Client = {},
})

--[=[
	Initializes the placement registry, sync bridge, and request handler.
	@within PlacementContext
]=]
-- Register the placement stack before any remote invocation can reach it.
function PlacementContext:KnitInit()
	local registry = Registry.new("Server")

	registry:Register("BlinkSyncServer", BlinkSyncServer)
	registry:Register("BlinkRemoteServer", BlinkRemoteServer)
	registry:Register("PlacementValidator", PlacementValidator.new(), "Domain")
	registry:Register("PlacementService", PlacementService.new(), "Infrastructure")
	registry:Register("PlacementSyncService", PlacementSyncService.new(), "Infrastructure")
	registry:Register("PlaceStructurePolicy", PlaceStructurePolicy.new(), "Domain")
	registry:Register("PlaceStructureCommand", PlaceStructureCommand.new(), "Application")
	registry:Register("GetPlacedStructuresQuery", GetPlacedStructuresQuery.new(), "Application")
	registry:InitAll()

	self._registry = registry
	self._runContext = nil
	self._validator = registry:Get("PlacementValidator")
	self._syncService = registry:Get("PlacementSyncService")
	self._placementService = registry:Get("PlacementService")
	self._placeStructureCommand = registry:Get("PlaceStructureCommand")
	self._getPlacedStructuresQuery = registry:Get("GetPlacedStructuresQuery")
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
	local runContext = Knit.GetService("RunContext")
	local worldContext = Knit.GetService("WorldContext")
	local economyContext = Knit.GetService("EconomyContext")
	self._runContext = runContext

	self._registry:Register("RunContext", runContext)
	self._registry:Register("WorldContext", worldContext)
	self._registry:Register("EconomyContext", economyContext)
	self._registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Late joiners need the current placement atom immediately after they connect.
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self._syncService:HydratePlayer(player)
	end)

	-- Existing players must be hydrated before the first placement event can reach them.
	for _, player in Players:GetPlayers() do
		self._syncService:HydratePlayer(player)
	end

	-- RunEnd is the cleanup boundary for all spawned structures and synced records.
	self._stateChangedConnection = self._runContext.StateChanged:Connect(function(newState: string, _previousState: string)
		if newState == "RunEnd" then
			self._placementService:DestroyAll()
			self._syncService:ClearAll()
		end
	end)
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
		return self._placeStructureCommand:Execute(player, validatedResult.value.coord, validatedResult.value.structureType)
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
	Disconnects listeners and tears down the sync bridge.
	@within PlacementContext
]=]
-- Disconnect listeners and tear down the sync bridge when the service shuts down.
function PlacementContext:Destroy()
	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
	end

	if self._stateChangedConnection then
		self._stateChangedConnection:Disconnect()
	end

	if self._syncService then
		self._syncService:Destroy()
	end

	if self._structurePlacedSignal then
		self._structurePlacedSignal:Destroy()
	end
end

WrapContext(PlacementContext, "Placement")

return PlacementContext
