--!strict

--[[
Module: PlacementController
Purpose: Owns client-side placement replication startup and the UI-facing accessor for placement state.
Used In System: Started by Knit on the client before placement UI hooks subscribe to the atom.
High-Level Flow: Create sync wrapper -> start Blink/atom subscription -> expose read access to UI consumers.
Boundaries: Does not own placement validation, spawning, or server-authoritative mutation.
]]

-- [Dependencies]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local PlacementTypes = require(game:GetService("ReplicatedStorage").Contexts.Placement.Types.PlacementTypes)
local PlacementSyncClient = require(script.Parent.Infrastructure.PlacementSyncClient)

type PlacementAtom = PlacementTypes.PlacementAtom

-- [Public API]

--[=[
	@class PlacementController
	Starts client-side placement sync and exposes placement atom accessors.
	@client
]=]
local PlacementController = Knit.CreateController({
	Name = "PlacementController",
})

--[=[
	Initializes the client-side placement sync client.
	@within PlacementController
]=]
-- Initialize the client sync wrapper before Start so it can subscribe immediately.
function PlacementController:KnitInit()
	self._syncClient = PlacementSyncClient.new()
end

--[=[
	Starts placement replication on the client.
	@within PlacementController
]=]
-- Start placement replication once the client runtime is ready.
function PlacementController:KnitStart()
	self._syncClient:Start()
end

--[=[
	Returns the local placement atom.
	@within PlacementController
	@return PlacementAtom -- The client placement atom.
]=]
-- Expose the local placement atom to UI consumers.
function PlacementController:GetAtom(): PlacementAtom
	return self._syncClient:GetAtom()
end

return PlacementController
