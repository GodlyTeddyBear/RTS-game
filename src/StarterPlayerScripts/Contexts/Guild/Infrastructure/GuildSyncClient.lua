--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Guild.Sync.SharedAtoms)

--[[
	Client-Side Guild Sync

	Server sends: { type = "init", data = { adventurers = { [adventurerId]: TAdventurer } } }
	Client stores: AdventurersAtom = { [string]: TAdventurer }
]]

local GuildSyncClient = setmetatable({}, { __index = BaseSyncClient })
GuildSyncClient.__index = GuildSyncClient

function GuildSyncClient.new(BlinkClient: any)
	local self = BaseSyncClient.new(BlinkClient, "SyncAdventurers", "adventurers", SharedAtoms.CreateClientAtom)
	return setmetatable(self, GuildSyncClient)
end

function GuildSyncClient:GetAdventurersAtom()
	return self:GetAtom()
end

return GuildSyncClient
