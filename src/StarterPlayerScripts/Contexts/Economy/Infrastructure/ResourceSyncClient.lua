--!strict

--[[
	Module: ResourceSyncClient
	Purpose: Wraps the client-side economy wallet atom and Blink listener.
	Used In System: Constructed by EconomyController and started during Knit controller startup.
	Boundaries: Owns client sync setup only; does not own wallet interpretation or UI subscriptions.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Economy.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.ResourceSyncClient)

--[=[
	@class ResourceSyncClient
	Wraps the client-side economy wallet atom and Blink listener.
	@client
]=]
local ResourceSyncClient = setmetatable({}, { __index = BaseSyncClient })
ResourceSyncClient.__index = ResourceSyncClient

-- [Initialization]

--[=[
	Creates a new client sync wrapper for the economy wallet atom.
	@within ResourceSyncClient
	@return ResourceSyncClient -- The new client sync wrapper.
]=]
function ResourceSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncResources", "resources", SharedAtoms.CreateClientAtom)
	return setmetatable(self, ResourceSyncClient)
end

-- [Public API]

--[=[
	Starts listening for server wallet sync payloads.
	@within ResourceSyncClient
]=]
function ResourceSyncClient:Start()
	BaseSyncClient.Start(self)
end

--[=[
	Returns the local wallet atom for subscriptions.
	@within ResourceSyncClient
	@return any -- The client Charm atom.
]=]
function ResourceSyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return ResourceSyncClient
