--!strict

--[[
Module: PlacementSyncClient
Purpose: Owns the client-side Blink sync wrapper that keeps the placement atom hydrated.
Used In System: Created by PlacementController during KnitInit and started during KnitStart.
High-Level Flow: Build sync wrapper -> subscribe to Blink placement channel -> expose atom read access.
Boundaries: Does not own placement rules, server mutation, or UI rendering.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Placement.Sync.SharedAtoms)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local BlinkClient = require(ReplicatedStorage.Network.Generated.PlacementSyncClient)

type PlacementAtom = PlacementTypes.PlacementAtom

-- [Public API]

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
	@return PlacementAtom -- The client atom.
]=]
-- Expose the local atom for UI subscriptions and read hooks.
function PlacementSyncClient:GetAtom(): PlacementAtom
	return BaseSyncClient.GetAtom(self)
end

return PlacementSyncClient
