--!strict

--[[
	DialogueState - Client-side atom for dialogue UI state

	Drives the React DialogueUI component. The DialogueManager updates this atom
	when the player interacts with an NPC, selects options, or ends dialogue.
	The React component subscribes via useAtom() for reactive updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type TDialogueOption = {
	Text: string,
	Index: number,
}

export type TDialogueState = {
	Active: boolean,
	NPCName: string,
	NPCText: string,
	DisplayText: string?,
	Options: { TDialogueOption },
}

local DEFAULT_STATE: TDialogueState = table.freeze({
	Active = false,
	NPCName = "",
	NPCText = "",
	DisplayText = nil,
	Options = {},
})

local dialogueAtom = Charm.atom(DEFAULT_STATE)

return {
	dialogueAtom = dialogueAtom,
	DEFAULT_STATE = DEFAULT_STATE,
}
