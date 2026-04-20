--!strict

--[=[
	@class DialogueSessionService
	Infrastructure service managing active dialogue sessions for players. Tracks which NPC and node each player is currently in.
	@server
]=]

--[=[
	@interface DialogueSession
	Represents an active dialogue session.
	.NPCId string -- The NPC being conversed with
	.NodeId string -- The current dialogue node ID
]=]
export type TDialogueSession = {
	NPCId: string,
	NodeId: string,
}

local DialogueSessionService = {}
DialogueSessionService.__index = DialogueSessionService

export type TDialogueSessionService = typeof(setmetatable({} :: {
	_Sessions: { [number]: TDialogueSession },
}, DialogueSessionService))

function DialogueSessionService.new(): TDialogueSessionService
	return setmetatable({
		_Sessions = {},
	}, DialogueSessionService)
end

--[=[
	Create or overwrite a dialogue session for a player.
	@within DialogueSessionService
	@param userId number -- The player's user ID
	@param npcId string -- The NPC to talk to
	@param nodeId string -- The starting node ID
]=]
function DialogueSessionService:StartSession(userId: number, npcId: string, nodeId: string)
	self._Sessions[userId] = {
		NPCId = npcId,
		NodeId = nodeId,
	}
end

--[=[
	Retrieve the active session for a player.
	@within DialogueSessionService
	@param userId number -- The player's user ID
	@return DialogueSession? -- The session, or nil if none exists
]=]
function DialogueSessionService:GetSession(userId: number): TDialogueSession?
	return self._Sessions[userId]
end

--[=[
	Advance the current dialogue node within an active session.
	@within DialogueSessionService
	@param userId number -- The player's user ID
	@param nodeId string -- The new node ID to advance to
]=]
function DialogueSessionService:SetNodeId(userId: number, nodeId: string)
	local session = self._Sessions[userId]
	if not session then
		return
	end

	session.NodeId = nodeId
end

--[=[
	Terminate a player's dialogue session.
	@within DialogueSessionService
	@param userId number -- The player's user ID
]=]
function DialogueSessionService:EndSession(userId: number)
	self._Sessions[userId] = nil
end

return DialogueSessionService
