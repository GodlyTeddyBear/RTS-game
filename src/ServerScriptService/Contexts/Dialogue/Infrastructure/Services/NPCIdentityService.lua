--!strict

--[=[
	@class NPCIdentityService
	Infrastructure service providing NPC identity lookups from the dialogue config.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueConfig = require(ReplicatedStorage.Contexts.Dialogue.Config.DialogueConfig)

local NPCIdentityService = {}
NPCIdentityService.__index = NPCIdentityService

export type TNPCIdentityService = typeof(setmetatable({}, NPCIdentityService))

function NPCIdentityService.new(): TNPCIdentityService
	return setmetatable({}, NPCIdentityService)
end

--[=[
	Check if an NPC ID refers to a valid dialogue-enabled NPC.
	@within NPCIdentityService
	@param npcId string -- The NPC identifier
	@return boolean -- True if the NPC exists in config
]=]
function NPCIdentityService:IsDialogueNPC(npcId: string): boolean
	return DialogueConfig.NPCS[npcId] ~= nil
end

--[=[
	Get the human-readable display name for an NPC.
	@within NPCIdentityService
	@param npcId string -- The NPC identifier
	@return string -- The display name, or the NPC ID if not found
]=]
function NPCIdentityService:GetDisplayName(npcId: string): string
	local entry = DialogueConfig.NPCS[npcId]
	if not entry then
		return npcId
	end
	return entry.DisplayName
end

return NPCIdentityService
