--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RunSyncClient = require(script.Parent.Infrastructure.RunSyncClient)

--[=[
	@class RunController
	Starts the client run sync atom for run UI consumers.
	@client
]=]
local RunController = Knit.CreateController({
	Name = "RunController",
})

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

--[=[
	Returns the local run atom for read hooks and UI subscriptions.
	@within RunController
	@return any -- The client run atom.
]=]
function RunController:GetAtom()
	return self._syncClient:GetAtom()
end

return RunController
