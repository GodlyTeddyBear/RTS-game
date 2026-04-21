--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Placement.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.PlacementSyncClient)

--[=[
	@class PlacementSyncClient
	Wraps client placement atom sync through Blink + Charm-sync.
	@client
]=]
local PlacementSyncClient = setmetatable({}, { __index = BaseSyncClient })
PlacementSyncClient.__index = PlacementSyncClient

--[=[
	Creates a new placement sync client wrapper.
	@within PlacementSyncClient
	@return PlacementSyncClient -- The new sync wrapper.
]=]
-- Mirror the server atom shape so client hydration can stay zero-conversion.
function PlacementSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncPlacements", "placements", SharedAtoms.CreateClientAtom)
	return setmetatable(self, PlacementSyncClient)
end

--[=[
	Starts listening for placement atom updates.
	@within PlacementSyncClient
]=]
-- Start listening for placement deltas from the server.
function PlacementSyncClient:Start()
	BaseSyncClient.Start(self)
end

--[=[
	Returns the local placement atom.
	@within PlacementSyncClient
	@return any -- The client atom.
]=]
-- Expose the local atom for UI subscriptions and read hooks.
function PlacementSyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return PlacementSyncClient
