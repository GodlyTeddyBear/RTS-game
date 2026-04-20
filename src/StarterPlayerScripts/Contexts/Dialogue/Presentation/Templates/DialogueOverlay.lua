--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local useDialogueController = require(script.Parent.Parent.Parent.Application.Hooks.useDialogueController)
local DialogueModal = require(script.Parent.Parent.Organisms.DialogueModal)

local e = React.createElement

--[=[
	@function DialogueOverlay
	@within DialogueOverlay
	Screen template that conditionally renders the dialogue modal when active.
	@return Frame? -- The dialogue modal, or nil if no active dialogue
	@client
]=]
local function DialogueOverlay()
	local controller = useDialogueController()
	if not controller.isActive then
		return nil
	end

	return e(DialogueModal, {
		NPCName = controller.npcName,
		DialogueText = controller.dialogueText,
		Options = controller.options,
		OptionsCanvasHeight = controller.optionsCanvasHeight,
		OnSelectOption = controller.onSelectOption,
		OnClose = controller.onClose,
	})
end

return DialogueOverlay
