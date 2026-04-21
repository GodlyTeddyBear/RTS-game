--!strict

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local PlacementSyncClient = require(script.Parent.Infrastructure.PlacementSyncClient)

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
	@return any -- The client placement atom.
]=]
-- Expose the local placement atom to UI consumers.
function PlacementController:GetAtom()
	return self._syncClient:GetAtom()
end

return PlacementController
