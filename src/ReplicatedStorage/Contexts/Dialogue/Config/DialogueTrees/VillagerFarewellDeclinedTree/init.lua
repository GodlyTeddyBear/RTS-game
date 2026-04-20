--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueTree = DialogueTypes.TDialogueTree

local VillagerFarewellDeclinedTree: TDialogueTree = {
	NPCId = "VillagerFarewellDeclined",
	DisplayName = "Villager",
	RootNodeId = "root",
	Nodes = {
		root = {
			Id = "root",
			Text = "No trouble. Perhaps another time.",
			Options = {
				{
					Id = "villager_farewell_declined_goodbye",
					Text = "Goodbye.",
					EndDialogue = true,
				},
			},
		},
	},
}

return VillagerFarewellDeclinedTree
