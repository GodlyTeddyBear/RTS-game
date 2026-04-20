--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Building.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.BuildingSyncClient)

--[=[
	@class BuildingSyncClient
	Syncs building state from server to client via Blink events.
	@client
]=]
local BuildingSyncClient = setmetatable({}, { __index = BaseSyncClient })
BuildingSyncClient.__index = BuildingSyncClient

--[=[
	Creates a new BuildingSyncClient instance.
	@within BuildingSyncClient
	@return BuildingSyncClient -- A new sync client subscribed to building updates
]=]
function BuildingSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncBuildings", "buildings", SharedAtoms.CreateClientAtom)
	return setmetatable(self, BuildingSyncClient)
end

--[=[
	Retrieves the buildings atom for UI subscription.
	@within BuildingSyncClient
	@return Charm.Atom -- The reactive buildings atom
]=]
function BuildingSyncClient:GetBuildingsAtom()
	return self:GetAtom()
end

return BuildingSyncClient
