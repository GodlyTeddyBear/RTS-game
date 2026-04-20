--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueTree = DialogueTypes.TDialogueTree

local VillagerCustomerNoOfferTree: TDialogueTree = {
	NPCId = "VillagerCustomerNoOffer",
	DisplayName = "Villager",
	RootNodeId = "root",
	Nodes = {
		root = {
			Id = "root",
			Text = "Hmm, I'm still preparing my wares. Check back shortly.",
			Options = {
				{
					Id = "villager_no_offer_goodbye",
					Text = "I'll return soon.",
					EndDialogue = true,
				},
			},
		},
	},
}

return VillagerCustomerNoOfferTree
