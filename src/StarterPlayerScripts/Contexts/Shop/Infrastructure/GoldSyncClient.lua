--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Shop.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.GoldSyncClient)

--[=[
	@class GoldSyncClient
	Synchronizes the player's gold balance from the server via Blink transport and exposes it as an atom.
	@client
]=]
local GoldSyncClient = setmetatable({}, { __index = BaseSyncClient })
GoldSyncClient.__index = GoldSyncClient

--[=[
	Construct a new GoldSyncClient.
	@within GoldSyncClient
	@return GoldSyncClient
]=]
function GoldSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncGold", "gold", SharedAtoms.CreateClientAtom)
	return setmetatable(self, GoldSyncClient)
end

--[=[
	Retrieve the reactive gold atom.
	@within GoldSyncClient
	@return Atom -- The gold balance atom
]=]
function GoldSyncClient:GetGoldAtom()
	return self:GetAtom()
end

return GoldSyncClient
