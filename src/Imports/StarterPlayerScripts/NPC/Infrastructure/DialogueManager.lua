--!strict

--[[
	DialogueManager - Manages dialogue for a single NPC

	Handles:
	- ProximityPrompt creation on NPC model
	- Dialogue tree traversal (nodes, options, conditions)
	- DialogueState atom updates for React UI rendering
	- Tree swapping based on flag conditions
	- Fires server remote for InteractWithNPC on dialogue start

	Uses DialogueHelpers data structures (PascalCase keys):
	- Node: { Text, Options, DialogueTree, Condition, FailCallback }
	- Option: { Text, Next, Callback, DisplayText, Condition, FailCallback, AutoAdvance }
]]

local NPCConfig = require(game:GetService("ReplicatedStorage").Contexts.NPC.Config.NPCConfig)
local DialogueState = require(script.Parent.Parent.Presentation.State.DialogueState)

local DialogueManager = {}
DialogueManager.__index = DialogueManager

--[=[
	Creates a new DialogueManager for a single NPC.

	@param npcModel Model - The NPC workspace model (must have PrimaryPart)
	@param npcId string - The NPC identifier (matches NPCConfig key)
	@param dialogueRegistry any - DialogueRegistry for loading tree definitions
	@param flagReader (string) -> any - Reads a flag value from the client atom
	@param flagSetter (string, any) -> () - Fires a remote to set a flag on the server
	@param serverContext any - NPCContext Knit service for remote calls
	@return DialogueManager - New manager instance
]=]
function DialogueManager.new(
	npcModel: Model,
	npcId: string,
	dialogueRegistry: any,
	flagReader: (string) -> any,
	flagSetter: (string, any) -> (),
	serverContext: any
)
	local self = setmetatable({}, DialogueManager)

	self._npcModel = npcModel
	self._npcId = npcId
	self._dialogueRegistry = dialogueRegistry
	self._flagReader = flagReader
	self._flagSetter = flagSetter
	self._serverContext = serverContext
	self._treeSelectors = {} :: { { FlagName: string, FlagValue: any, TreeVariant: string } }
	self._currentTree = nil :: any
	self._currentNodeIndex = 0
	self._inDialogue = false
	self._pendingNextIndex = nil :: number?
	self._prompt = nil :: ProximityPrompt?
	self._promptConnection = nil :: RBXScriptConnection?

	self:_Initialize()

	return self
end

--[=[
	Registers a tree swap rule: when a flag matches a value, use a different tree variant.
	The manager checks these rules in order during _SelectTreeVariant().
	First matching rule wins. If no rules match, uses default ("Greeting").

	@param flagName string - The flag to check
	@param flagValue any - The value that triggers this variant
	@param treeVariant string - The dialogue tree variant to load
]=]
function DialogueManager:AddTreeSelector(flagName: string, flagValue: any, treeVariant: string)
	table.insert(self._treeSelectors, {
		FlagName = flagName,
		FlagValue = flagValue,
		TreeVariant = treeVariant,
	})
end

function DialogueManager:_Initialize()
	local primaryPart = self._npcModel.PrimaryPart
	if not primaryPart then
		warn("[DialogueManager] NPC model has no PrimaryPart:", self._npcId)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = self:_GetDisplayName()
	prompt.MaxActivationDistance = 15
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = primaryPart
	self._prompt = prompt

	self._promptConnection = prompt.Triggered:Connect(function()
		if self._inDialogue then
			return
		end
		self:_StartDialogue()
	end)
end

function DialogueManager:_GetDisplayName(): string
	local config = NPCConfig[self._npcId]
	if config then
		return config.DisplayName
	end
	return self._npcId
end

--- Selects which tree variant to load based on current flag state.
function DialogueManager:_SelectTreeVariant(): string?
	for _, selector in ipairs(self._treeSelectors) do
		local currentValue = self._flagReader(selector.FlagName)
		if currentValue == selector.FlagValue then
			if self._dialogueRegistry:Exists(self._npcId, selector.TreeVariant) then
				return selector.TreeVariant
			end
		end
	end
	return nil
end

--- Builds the dialogue tree from the registry using current flags.
function DialogueManager:_BuildTree(): any?
	local variant = self:_SelectTreeVariant()
	local treeFactory = self._dialogueRegistry:Get(self._npcId, variant)

	if treeFactory then
		return treeFactory(self._flagReader, self._flagSetter, self._npcId)
	end
	return nil
end

--- Starts a new dialogue session.
function DialogueManager:_StartDialogue()
	-- Notify server (auto-sets HasMet flag)
	if self._serverContext then
		task.spawn(function()
			local _ = self._serverContext:InteractWithNPC(self._npcId)
		end)
	end

	-- Build tree with current flags
	local tree = self:_BuildTree()
	if not tree or #tree == 0 then
		warn("[DialogueManager] No dialogue tree for NPC:", self._npcId)
		return
	end

	self._currentTree = tree
	self._inDialogue = true

	-- Display first valid node
	self:_DisplayNode(1)
end

--- Displays a specific node by index, evaluating conditions.
--- Walks forward from nodeIndex to find a node whose condition passes.
function DialogueManager:_DisplayNode(nodeIndex: number)
	if not self._currentTree then
		self:_EndDialogue()
		return
	end

	local tree = self._currentTree
	local index = nodeIndex

	while index >= 1 and index <= #tree do
		local node = tree[index]

		-- Check node condition
		if not self:_IsNodeValid(node) then
			index = index + 1
			continue
		end

		-- Node is valid — display it
		self._currentNodeIndex = index
		self:_UpdateAtom(node)
		return
	end

	-- No valid node found
	self:_EndDialogue()
end

--- Evaluates whether a node's condition passes, firing FailCallback if it fails.
function DialogueManager:_IsNodeValid(node: any): boolean
	if not node.Condition then
		return true
	end

	local conditionPassed = self:_EvaluateCondition(node.Condition)
	if not conditionPassed and node.FailCallback then
		pcall(node.FailCallback)
	end

	return conditionPassed
end

--- Safely evaluates a condition function with pcall.
function DialogueManager:_EvaluateCondition(condition: any): boolean
	local success, result = pcall(condition)
	return success and result or false
end

--- Checks if an option should be visible based on its condition.
function DialogueManager:_IsOptionVisible(option: any): boolean
	if not option.Condition then
		return true
	end
	return self:_EvaluateCondition(option.Condition)
end

--- Filters options to show only visible ones (excluding auto-advance).
function DialogueManager:_FilterVisibleOptions(options: any): { { Text: string, Index: number } }
	local visibleOptions: { { Text: string, Index: number } } = {}

	if not options then
		return visibleOptions
	end

	for i, option in ipairs(options) do
		if self:_IsOptionVisible(option) and not option.AutoAdvance then
			table.insert(visibleOptions, {
				Text = option.Text,
				Index = i,
			})
		end
	end

	return visibleOptions
end

--- Finds the auto-advance option in the list, if present.
function DialogueManager:_FindAutoAdvanceOption(options: any): any?
	if not options then
		return nil
	end

	for _, option in ipairs(options) do
		if option.AutoAdvance then
			return option
		end
	end

	return nil
end

--- Builds the options list for the UI, handling auto-advance and empty cases.
function DialogueManager:_BuildOptionsForUI(visibleOptions: { { Text: string, Index: number } }, node: any): { { Text: string, Index: number } }
	if #visibleOptions > 0 then
		return visibleOptions
	end

	-- No visible options: check for auto-advance or end dialogue
	local autoAdvanceOption = self:_FindAutoAdvanceOption(node.Options)
	if autoAdvanceOption then
		return {
			{
				Text = "[Continue]",
				Index = -99,
			},
		}
	end

	return {
		{
			Text = "[End conversation]",
			Index = -1,
		},
	}
end

--- Updates the DialogueState atom with the current node's data.
function DialogueManager:_UpdateAtom(node: any)
	-- Filter options by conditions
	local visibleOptions = self:_FilterVisibleOptions(node.Options)

	-- Build final options list (handle auto-advance or empty cases)
	local finalOptions = self:_BuildOptionsForUI(visibleOptions, node)

	DialogueState.dialogueAtom({
		Active = true,
		NPCName = self:_GetDisplayName(),
		NPCText = node.Text,
		DisplayText = nil,
		Options = finalOptions,
	})
end

--- Called by NPCController when player selects an option.
function DialogueManager:SelectOption(optionIndex: number)
	if not self._inDialogue or not self._currentTree then
		return
	end

	-- Handle special option codes
	if optionIndex == -1 then
		self:_HandleEndDialogue()
		return
	end

	if optionIndex == -98 then
		self:_HandleDisplayTextContinue()
		return
	end

	if optionIndex == -99 then
		self:_HandleAutoAdvance()
		return
	end

	-- Handle normal option selection
	self:_HandleOptionSelection(optionIndex)
end

--- Handles end dialogue option.
function DialogueManager:_HandleEndDialogue()
	self:_EndDialogue()
end

--- Handles continue after display text option.
function DialogueManager:_HandleDisplayTextContinue()
	local nextIndex: number = self._pendingNextIndex or -1
	self._pendingNextIndex = nil
	self:_NavigateToNext(nextIndex)
end

--- Handles auto-advance option selection.
function DialogueManager:_HandleAutoAdvance()
	local node = self._currentTree[self._currentNodeIndex]
	if not node or not node.Options then
		self:_EndDialogue()
		return
	end

	for _, option in ipairs(node.Options) do
		if not option.AutoAdvance then
			continue
		end

		if option.Callback then
			pcall(option.Callback)
		end

		local nextIndex = option.Next or -1
		self:_ResolveNextIndexAndNavigate(nextIndex, option.ShouldEndDialogue)
		return
	end

	self:_EndDialogue()
end

--- Handles normal option selection by player.
function DialogueManager:_HandleOptionSelection(optionIndex: number)
	local node = self._currentTree[self._currentNodeIndex]
	if not node or not node.Options or not node.Options[optionIndex] then
		self:_EndDialogue()
		return
	end

	local option = node.Options[optionIndex]

	-- Fire option callback
	if option.Callback then
		pcall(option.Callback)
	end

	-- Show displayText if present (NPC response to player choice)
	if option.DisplayText then
		DialogueState.dialogueAtom({
			Active = true,
			NPCName = self:_GetDisplayName(),
			NPCText = node.Text,
			DisplayText = option.DisplayText,
			Options = {
				{
					Text = "[Continue]",
					Index = -98,
				},
			},
		})
		self._pendingNextIndex = option.Next or -1
		return
	end

	-- Navigate to next node
	self:_NavigateToNext(option.Next or -1)
end

--- Navigates to the next node based on index.
--- -1 ends dialogue, 0 repeats current node, >0 goes to that node.
function DialogueManager:_NavigateToNext(nextIndex: number)
	self:_ResolveNextIndexAndNavigate(nextIndex, false)
end

--- Resolves a next index and navigates accordingly.
function DialogueManager:_ResolveNextIndexAndNavigate(nextIndex: number, shouldEnd: boolean?)
	if shouldEnd == true then
		self:_EndDialogue()
		return
	end

	if nextIndex == -1 then
		self:_EndDialogue()
	elseif nextIndex == 0 then
		self:_DisplayNode(self._currentNodeIndex)
	else
		self:_DisplayNode(nextIndex)
	end
end

--- Ends the dialogue session and clears the UI.
function DialogueManager:_EndDialogue()
	self._inDialogue = false
	self._currentTree = nil
	self._currentNodeIndex = 0
	self._pendingNextIndex = nil

	DialogueState.dialogueAtom(DialogueState.DEFAULT_STATE)
end

--- Returns whether this manager is currently in an active dialogue.
function DialogueManager:IsInDialogue(): boolean
	return self._inDialogue
end

--- Cleans up the DialogueManager.
function DialogueManager:Destroy()
	local promptConnection = self._promptConnection
	if promptConnection then
		promptConnection:Disconnect()
		self._promptConnection = nil
	end
	local prompt = self._prompt
	if prompt then
		prompt:Destroy()
		self._prompt = nil
	end
	if self._inDialogue then
		self:_EndDialogue()
	end
	self._treeSelectors = {}
end

return DialogueManager
