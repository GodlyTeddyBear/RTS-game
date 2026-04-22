--!strict

--[[
	Module: EconomyController
	Purpose: Starts the client economy sync wrapper used by read hooks and UI consumers.
	Used In System: Created by Knit on the client during controller startup.
	High-Level Flow: Create sync client -> start replication -> expose atom accessors.
	Boundaries: Owns controller lifecycle only; does not own atom shape, network transport, or UI state.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ResourceSyncClient = require(script.Parent.Infrastructure.ResourceSyncClient)

--[=[
	@class EconomyController
	Starts the client economy sync atom for economy UI consumers.
	@client
]=]
local EconomyController = Knit.CreateController({
	Name = "EconomyController",
})

-- [Initialization]

--[=[
	Initializes the economy sync client.
	@within EconomyController
]=]
function EconomyController:KnitInit()
	self._syncClient = ResourceSyncClient.new()
end

-- [Public API]

--[=[
	Starts wallet atom replication on the client.
	@within EconomyController
]=]
function EconomyController:KnitStart()
	self._syncClient:Start()
end

--[=[
	Returns the local resource wallet atom for read hooks and UI subscriptions.
	@within EconomyController
	@return any -- The client resource wallet atom.
]=]
function EconomyController:GetAtom()
	return self._syncClient:GetAtom()
end

return EconomyController
