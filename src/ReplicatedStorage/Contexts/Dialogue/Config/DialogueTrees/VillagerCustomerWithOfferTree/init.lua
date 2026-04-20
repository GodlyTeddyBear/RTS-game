--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueTree = DialogueTypes.TDialogueTree

local VillagerCustomerWithOfferTree: TDialogueTree = {
	NPCId = "VillagerCustomerWithOffer",
	DisplayName = "Villager",
	RootNodeId = "root",
	Nodes = {
		root = {
			Id = "root",
			Text = "A fine day for trading. What brings you my way?",
			Options = {
				{
					Id = "villager_view_offer",
					Text = "Let's see what you have.",
					EndDialogue = true,
				},
				{
					Id = "villager_goodbye",
					Text = "Not now, thanks.",
					EndDialogue = true,
				},
			},
		},
	},
}

return VillagerCustomerWithOfferTree
