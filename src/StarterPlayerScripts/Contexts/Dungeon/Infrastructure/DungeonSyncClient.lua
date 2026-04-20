--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Dungeon.Sync.SharedAtoms)

--[[
	Client-Side Dungeon Sync

	Server sends: { type = "init", data = { dungeonState = TDungeonState } }
	Client stores: DungeonStateAtom = TDungeonState
]]

local DungeonSyncClient = setmetatable({}, { __index = BaseSyncClient })
DungeonSyncClient.__index = DungeonSyncClient

function DungeonSyncClient.new(BlinkClient: any)
	local self = BaseSyncClient.new(BlinkClient, "SyncDungeonState", "dungeonState", SharedAtoms.CreateClientAtom)
	return setmetatable(self, DungeonSyncClient)
end

function DungeonSyncClient:GetDungeonStateAtom()
	return self:GetAtom()
end

return DungeonSyncClient
