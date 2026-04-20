--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Quest.Sync.SharedAtoms)

--[=[
	@class QuestSyncClient
	Client-side sync handler for quest state via Blink network protocol.
	Server sends: { type = "init", data = { questState = TQuestState } }
	Client stores: atom containing TQuestState
	@client
]=]

local QuestSyncClient = setmetatable({}, { __index = BaseSyncClient })
QuestSyncClient.__index = QuestSyncClient

--[=[
	Create a new QuestSyncClient to sync quest state from the server.
	@within QuestSyncClient
	@param BlinkClient any -- The Blink network client instance
	@return QuestSyncClient
]=]
function QuestSyncClient.new(BlinkClient: any)
	local self = BaseSyncClient.new(BlinkClient, "SyncQuestState", "questState", SharedAtoms.CreateClientAtom)
	return setmetatable(self, QuestSyncClient)
end

--[=[
	Get the Charm atom containing the current quest state.
	@within QuestSyncClient
	@return Charm atom -- Atom containing TQuestState
]=]
function QuestSyncClient:GetQuestStateAtom()
	return self:GetAtom()
end

return QuestSyncClient
