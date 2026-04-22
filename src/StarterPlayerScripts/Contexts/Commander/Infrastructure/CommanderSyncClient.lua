--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Commander.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.CommanderSyncClient)

--[=[
	@class CommanderSyncClient
	Owns the client commander atom and Blink listener used by read hooks.
	@client
]=]
local CommanderSyncClient = {}
CommanderSyncClient.__index = CommanderSyncClient
setmetatable(CommanderSyncClient, BaseSyncClient)

--[=[
	Creates a new commander sync client.
	@within CommanderSyncClient
	@return CommanderSyncClient -- The new sync client.
]=]
function CommanderSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncCommander", "commander", SharedAtoms.CreateClientAtom)
	return setmetatable(self, CommanderSyncClient)
end

--[=[
	Starts listening for commander sync payloads.
	@within CommanderSyncClient
]=]
function CommanderSyncClient:Start()
	BaseSyncClient.Start(self)
end

--[=[
	Returns the local commander atom for read subscriptions.
	@within CommanderSyncClient
	@return any -- The client commander atom.
]=]
function CommanderSyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return CommanderSyncClient
