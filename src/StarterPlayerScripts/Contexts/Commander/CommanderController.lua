--!strict

--[=[
	@class CommanderController
	Purpose: Owns the client commander sync wrapper and exposes the local commander atom to UI consumers.
	Used In System: Started by Knit on the client during player bootstrap and consumed by run HUD read hooks.
	High-Level Flow: Create sync client -> start replication -> expose atom for read subscriptions.
	Boundaries: Owns controller lifecycle only; does not own payload parsing, UI rendering, or authoritative commander state.
	@client
]=]
-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CommanderSyncClient = require(script.Parent.Infrastructure.CommanderSyncClient)

local CommanderController = Knit.CreateController({
	Name = "CommanderController",
})

-- [Initialization]

--[=[
	Initializes the commander sync client.
	@within CommanderController
]=]
function CommanderController:KnitInit()
	self._syncClient = CommanderSyncClient.new()
end

-- [Public API]

--[=[
	Starts commander atom replication on the client.
	@within CommanderController
]=]
function CommanderController:KnitStart()
	self._syncClient:Start()
end

--[=[
	Returns the local commander atom for read hooks and UI subscriptions.
	@within CommanderController
	@return any -- The client commander atom.
]=]
function CommanderController:GetAtom()
	return self._syncClient:GetAtom()
end

return CommanderController
