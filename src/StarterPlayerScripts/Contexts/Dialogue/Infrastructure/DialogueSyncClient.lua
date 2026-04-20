--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedAtoms = require(ReplicatedStorage.Contexts.Dialogue.Sync.SharedAtoms)

--[=[
	@class DialogueSyncClient
	Manages dialogue state synchronization between server and client using atoms.
	@client
]=]
local DialogueSyncClient = {}
DialogueSyncClient.__index = DialogueSyncClient

export type TDialogueSyncClient = typeof(setmetatable({} :: {
	DialogueStateAtom: any,
}, DialogueSyncClient))

--[=[
	Create a new DialogueSyncClient instance.
	@within DialogueSyncClient
	@return TDialogueSyncClient -- A new sync client
]=]
function DialogueSyncClient.new(): TDialogueSyncClient
	return setmetatable({
		DialogueStateAtom = SharedAtoms.CreateDialogueStateAtom(),
	}, DialogueSyncClient)
end

--[=[
	Get the dialogue state atom for subscribing to state changes.
	@within DialogueSyncClient
	@return any -- The dialogue state atom
]=]
function DialogueSyncClient:GetDialogueStateAtom()
	return self.DialogueStateAtom
end

--[=[
	Update the dialogue state atom with a new snapshot.
	@within DialogueSyncClient
	@param snapshot any -- The new dialogue state snapshot
]=]
function DialogueSyncClient:SetSnapshot(snapshot: any)
	self.DialogueStateAtom(snapshot)
end

--[=[
	Reset the dialogue state to the default snapshot.
	@within DialogueSyncClient
]=]
function DialogueSyncClient:Reset()
	self.DialogueStateAtom(SharedAtoms.DEFAULT_SNAPSHOT)
end

return DialogueSyncClient
