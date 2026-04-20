--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local dialogueController = nil

local function getController()
	if dialogueController == nil then
		dialogueController = Knit.GetController("DialogueController")
	end
	return dialogueController
end

--[=[
	@function useDialogueActions
	@within useDialogueActions
	Write hook that provides dialogue action callbacks.
	@return { selectOption: (optionId: string) -> (), closeDialogue: () -> () } -- Action callbacks
]=]
local function useDialogueActions()
	-- Selects a dialogue option and advances the conversation.
	local function selectOption(optionId: string)
		local controller = getController()
		if not controller then
			return
		end
		controller:SelectDialogueOption(optionId)
	end

	-- Closes the current dialogue session.
	local function closeDialogue()
		local controller = getController()
		if not controller then
			return
		end
		controller:EndDialogueSession()
	end

	return {
		selectOption = selectOption,
		closeDialogue = closeDialogue,
	}
end

return useDialogueActions
