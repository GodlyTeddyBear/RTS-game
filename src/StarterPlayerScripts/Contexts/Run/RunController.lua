--!strict

--[[
    Module: RunController
    Purpose: Owns the client entry point for run-state replication and exposes the local atom to UI hooks.
    Used In System: Loaded by Knit on the client to initialize and start the run sync client.
    Boundaries: Does not own server run rules, state transitions, or sync payload generation.
    High-Level Flow: Create sync client -> start replication -> expose atom to hooks.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RunSyncClient = require(script.Parent.Infrastructure.RunSyncClient)

--[=[
	@class RunController
	Starts the client run sync atom for run UI consumers.
	High-Level Flow: Create sync client -> start replication -> expose atom to hooks.
	@client
]=]
local RunController = Knit.CreateController({
	Name = "RunController",
})

-- [Lifecycle]

--[=[
	Initializes the run sync client.
	@within RunController
]=]
function RunController:KnitInit()
	self._syncClient = RunSyncClient.new()
end

--[=[
	Starts run atom replication on the client.
	@within RunController
]=]
function RunController:KnitStart()
	self._syncClient:Start()
end

-- [Public API]

--[=[
	Returns the local run atom for read hooks and UI subscriptions.
	@within RunController
	@return any -- The client run atom.
]=]
function RunController:GetAtom()
	return self._syncClient:GetAtom()
end

return RunController
