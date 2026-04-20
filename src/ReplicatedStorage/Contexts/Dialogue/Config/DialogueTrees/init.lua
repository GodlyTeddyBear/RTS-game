--!strict

local DialogueTypes = require(script.Parent.Parent.Types.DialogueTypes)

type TDialogueTree = DialogueTypes.TDialogueTree

local GuideTree = require(script.GuideTree)
local VillagerCustomerNoOfferTree = require(script.VillagerCustomerNoOfferTree)
local VillagerCustomerWithOfferTree = require(script.VillagerCustomerWithOfferTree)
local VillagerFarewellAcceptedTree = require(script.VillagerFarewellAcceptedTree)
local VillagerFarewellDeclinedTree = require(script.VillagerFarewellDeclinedTree)

local DialogueTrees: { [string]: TDialogueTree } = {
	Eldric = GuideTree,
	VillagerCustomerNoOffer = VillagerCustomerNoOfferTree,
	VillagerCustomerWithOffer = VillagerCustomerWithOfferTree,
	VillagerFarewellAccepted = VillagerFarewellAcceptedTree,
	VillagerFarewellDeclined = VillagerFarewellDeclinedTree,
}

return table.freeze(DialogueTrees)
