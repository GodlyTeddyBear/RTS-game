--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

local dialogueStateAtom = nil

--[=[
	@function useDialogueState
	@within useDialogueState
	Read hook that subscribes to dialogue state changes.
	@return any? -- The current dialogue state, or nil if controller is not ready
]=]
local function useDialogueState()
	if dialogueStateAtom == nil then
		local dialogueController = Knit.GetController("DialogueController")
		if not dialogueController then
			return nil
		end
		dialogueStateAtom = dialogueController:GetDialogueStateAtom()
	end

	return useAtom(dialogueStateAtom)
end

return useDialogueState
