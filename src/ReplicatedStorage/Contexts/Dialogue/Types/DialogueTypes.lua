--!strict

local FlagTypes = require(script.Parent.FlagTypes)

export type TFlagValue = FlagTypes.TFlagValue
export type TPlayerFlags = FlagTypes.TPlayerFlags

export type TDialogueOption = {
	Id: string,
	Text: string,
}

export type TDialogueSnapshot = {
	Active: boolean,
	NPCId: string?,
	NPCName: string?,
	NodeId: string?,
	Text: string?,
	Options: { TDialogueOption },
}

export type TDialogueNodeOption = {
	Id: string,
	Text: string,
	NextNodeId: string?,
	EndDialogue: boolean?,
	RequiredFlags: TPlayerFlags?,
	SetFlags: TPlayerFlags?,
}

export type TDialogueNode = {
	Id: string,
	Text: string,
	Options: { TDialogueNodeOption },
}

export type TDialogueTree = {
	NPCId: string,
	DisplayName: string,
	RootNodeId: string,
	Nodes: { [string]: TDialogueNode },
}

return {}
