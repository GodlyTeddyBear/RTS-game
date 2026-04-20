--!strict

--[=[
	@class DialogueTreeService
	Infrastructure service managing dialogue tree structure, option resolution, and snapshot building.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueTrees = require(ReplicatedStorage.Contexts.Dialogue.Config.DialogueTrees)
local DialogueTypes = require(ReplicatedStorage.Contexts.Dialogue.Types.DialogueTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err

type TPlayerFlags = DialogueTypes.TPlayerFlags
type TDialogueTree = DialogueTypes.TDialogueTree
type TDialogueNode = DialogueTypes.TDialogueNode
type TDialogueNodeOption = DialogueTypes.TDialogueNodeOption
type TDialogueSnapshot = DialogueTypes.TDialogueSnapshot

local DialogueTreeService = {}
DialogueTreeService.__index = DialogueTreeService

export type TOptionResolution = {
	NextNodeId: string?,
	EndDialogue: boolean,
	SetFlags: TPlayerFlags,
}

export type TDialogueTreeService = typeof(setmetatable({}, DialogueTreeService))

-- Evaluate whether player flags meet required conditions. Handles negation (false = must not be set/true).
local function _MatchesRequiredFlags(requiredFlags: TPlayerFlags?, playerFlags: TPlayerFlags): boolean
	if not requiredFlags then
		return true
	end

	for flagName, requiredValue in pairs(requiredFlags) do
		local actualValue = playerFlags[flagName]
		if requiredValue == false then
			if actualValue ~= nil and actualValue ~= false then
				return false
			end
		else
			if actualValue ~= requiredValue then
				return false
			end
		end
	end

	return true
end

-- Filter dialogue options, keeping only those where required flags are satisfied.
local function _FilterVisibleOptions(node: TDialogueNode, playerFlags: TPlayerFlags): { DialogueTypes.TDialogueOption }
	local options: { DialogueTypes.TDialogueOption } = {}

	for _, option in ipairs(node.Options) do
		if _MatchesRequiredFlags(option.RequiredFlags, playerFlags) then
			table.insert(options, {
				Id = option.Id,
				Text = option.Text,
			})
		end
	end

	return options
end

function DialogueTreeService.new(): TDialogueTreeService
	return setmetatable({}, DialogueTreeService)
end

--[=[
	Retrieve the dialogue tree for an NPC from config.
	@within DialogueTreeService
	@param npcId string -- The NPC identifier
	@return TDialogueTree? -- The tree, or nil if not found
]=]
function DialogueTreeService:GetTree(npcId: string): TDialogueTree?
	return DialogueTrees[npcId]
end

--[=[
	Get the root node ID for an NPC's dialogue tree.
	@within DialogueTreeService
	@param npcId string -- The NPC identifier
	@return string? -- The root node ID, or nil if tree not found
]=]
function DialogueTreeService:GetRootNodeId(npcId: string): string?
	local tree = self:GetTree(npcId)
	return tree and tree.RootNodeId or nil
end

--[=[
	Build a dialogue snapshot for the current node. Filters options based on player flags.
	@within DialogueTreeService
	@param npcId string -- The NPC identifier
	@param nodeId string -- The current node ID
	@param playerFlags table -- Player's dialogue flags for option filtering
	@return Result<DialogueSnapshot> -- Snapshot with node text and available options
]=]
function DialogueTreeService:BuildSnapshot(npcId: string, nodeId: string, playerFlags: TPlayerFlags): Result.Result<TDialogueSnapshot>
	local tree = self:GetTree(npcId)
	if not tree then
		return Err("DialogueTreeNotFound", Errors.DIALOGUE_TREE_NOT_FOUND)
	end

	local node = tree.Nodes[nodeId]
	if not node then
		return Err("DialogueNodeNotFound", Errors.DIALOGUE_NODE_NOT_FOUND)
	end

	local options = _FilterVisibleOptions(node, playerFlags)

	return Ok({
		Active = true,
		NPCId = tree.NPCId,
		NPCName = tree.DisplayName,
		NodeId = node.Id,
		Text = node.Text,
		Options = options,
	})
end

--[=[
	Resolve a selected option, validating flag requirements and extracting mutations and next node.
	@within DialogueTreeService
	@param npcId string -- The NPC identifier
	@param nodeId string -- The current node ID
	@param optionId string -- The chosen option ID
	@param playerFlags table -- Player's dialogue flags for option validation
	@return Result<OptionResolution> -- Next node ID, end flag, and flag mutations to apply
]=]
function DialogueTreeService:ResolveOption(
	npcId: string,
	nodeId: string,
	optionId: string,
	playerFlags: TPlayerFlags
): Result.Result<TOptionResolution>
	local tree = self:GetTree(npcId)
	if not tree then
		return Err("DialogueTreeNotFound", Errors.DIALOGUE_TREE_NOT_FOUND)
	end

	local node = tree.Nodes[nodeId]
	if not node then
		return Err("DialogueNodeNotFound", Errors.DIALOGUE_NODE_NOT_FOUND)
	end

	local selectedOption: TDialogueNodeOption? = nil
	for _, option in ipairs(node.Options) do
		if option.Id == optionId and _MatchesRequiredFlags(option.RequiredFlags, playerFlags) then
			selectedOption = option
			break
		end
	end

	if not selectedOption then
		return Err("DialogueOptionNotFound", Errors.DIALOGUE_OPTION_NOT_FOUND)
	end

	return Ok({
		NextNodeId = selectedOption.NextNodeId,
		EndDialogue = selectedOption.EndDialogue == true,
		SetFlags = selectedOption.SetFlags or {},
	})
end

return DialogueTreeService
