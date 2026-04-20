--!strict

--[=[
	@class DialogueViewModel
	Transforms raw dialogue snapshots into UI-ready view models.
	@client
]=]
local DialogueViewModel = {}

local OPTION_ROW_HEIGHT = 0.2
local OPTION_ROW_PADDING = 0.03

local function computeOptionsCanvasHeight(optionCount: number): number
	return optionCount * OPTION_ROW_HEIGHT
		+ math.max(0, optionCount - 1) * OPTION_ROW_PADDING
		+ OPTION_ROW_PADDING * 2
end

--[=[
	Create a ViewModel from a dialogue state snapshot.
	@within DialogueViewModel
	@param snapshot any -- The raw dialogue state snapshot
	@return { isActive: boolean, npcName: string, dialogueText: string, options: { any }, optionsCanvasHeight: number } -- Frozen view model
]=]
function DialogueViewModel.fromSnapshot(snapshot: any)
	if not snapshot then
		return table.freeze({
			isActive = false,
			npcName = "",
			dialogueText = "",
			options = {},
			optionsCanvasHeight = computeOptionsCanvasHeight(0),
		})
	end

	local options = snapshot.Options or {}
	return table.freeze({
		isActive = snapshot.Active == true,
		npcName = snapshot.NPCName or "",
		dialogueText = snapshot.Text or "",
		options = options,
		optionsCanvasHeight = computeOptionsCanvasHeight(#options),
	})
end

return DialogueViewModel
