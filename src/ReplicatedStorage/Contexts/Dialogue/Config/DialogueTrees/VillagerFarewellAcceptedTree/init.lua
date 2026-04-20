--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueTree = DialogueTypes.TDialogueTree

local VillagerFarewellAcceptedTree: TDialogueTree = {
	NPCId = "VillagerFarewellAccepted",
	DisplayName = "Villager",
	RootNodeId = "root",
	Nodes = {
		root = {
			Id = "root",
			Text = "Excellent. I'll hold up my end of the bargain.",
			Options = {
				{
					Id = "villager_farewell_accepted_goodbye",
					Text = "Goodbye.",
					EndDialogue = true,
				},
			},
		},
	},
}

return VillagerFarewellAcceptedTree
