--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CommanderSyncClient = require(script.Parent.Infrastructure.CommanderSyncClient)

--[=[
	@class CommanderController
	Starts the client commander sync atom for future UI consumers.
	@client
]=]
local CommanderController = Knit.CreateController({
	Name = "CommanderController",
})

--[=[
	Initializes the commander sync client.
	@within CommanderController
]=]
function CommanderController:KnitInit()
	self._syncClient = CommanderSyncClient.new()
end

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
