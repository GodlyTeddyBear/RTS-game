--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useDialogueState = require(script.Parent.useDialogueState)
local useDialogueActions = require(script.Parent.useDialogueActions)
local DialogueViewModel = require(script.Parent.Parent.ViewModels.DialogueViewModel)

--[=[
	@function useDialogueController
	@within useDialogueController
	Combined hook that provides dialogue UI state and actions via a ViewModel.
	@return { isActive: boolean, npcName: string, dialogueText: string, options: { any }, onSelectOption: (optionId: string) -> (), onClose: () -> () } -- Dialogue UI controller
]=]
local function useDialogueController()
	local dialogueState = useDialogueState()
	local actions = useDialogueActions()

	-- Memoize ViewModel to prevent unnecessary UI updates when actions change
	local viewModel = React.useMemo(function()
		return DialogueViewModel.fromSnapshot(dialogueState)
	end, { dialogueState })

	return {
		isActive = viewModel.isActive,
		npcName = viewModel.npcName,
		dialogueText = viewModel.dialogueText,
		options = viewModel.options,
		optionsCanvasHeight = viewModel.optionsCanvasHeight,
		onSelectOption = actions.selectOption,
		onClose = actions.closeDialogue,
	}
end

return useDialogueController
