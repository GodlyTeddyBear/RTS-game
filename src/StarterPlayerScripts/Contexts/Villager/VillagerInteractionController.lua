--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local VillagerInteractionAtom = require(script.Parent.Infrastructure.VillagerInteractionAtom)

local Events = GameEvents.Events

local VIEW_OFFER_OPTION_ID = "villager_view_offer"
local WITH_OFFER_NPC_ID = "VillagerCustomerWithOffer"
local NO_OFFER_NPC_ID = "VillagerCustomerNoOffer"

type TPendingVillager = {
	villagerId: string,
	offerId: string?,
	villagerName: string,
}

local VillagerInteractionController = Knit.CreateController({
	Name = "VillagerInteractionController",
})

function VillagerInteractionController:KnitStart()
	self._pendingVillager = nil :: TPendingVillager?

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		self:_HandlePromptTriggered(prompt, player)
	end)

	GameEvents.Bus:On(Events.Dialogue.OptionSelected, function(optionId: string)
		self:_HandleDialogueOptionSelected(optionId)
	end)
end

function VillagerInteractionController:_HandlePromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer then
		return
	end
	if prompt.Name ~= "VillagerPrompt" then
		return
	end

	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end

	local villagerId = model:GetAttribute("VillagerId")
	if type(villagerId) ~= "string" or villagerId == "" then
		return
	end

	local rawOfferId = model:GetAttribute("OfferId")
	local offerId = if type(rawOfferId) == "string" and rawOfferId ~= "" then rawOfferId else nil
	local rawDisplayName = model:GetAttribute("DisplayName")
	local villagerName = if type(rawDisplayName) == "string" and rawDisplayName ~= "" then rawDisplayName else "Villager"

	self._pendingVillager = {
		villagerId = villagerId,
		offerId = offerId,
		villagerName = villagerName,
	}

	local npcId = if offerId then WITH_OFFER_NPC_ID else NO_OFFER_NPC_ID
	Knit.GetController("DialogueController"):StartDialogueSession(npcId)
end

function VillagerInteractionController:_HandleDialogueOptionSelected(optionId: string)
	if optionId ~= VIEW_OFFER_OPTION_ID then
		return
	end

	local pendingVillager = self._pendingVillager
	if not pendingVillager or not pendingVillager.offerId then
		return
	end

	VillagerInteractionAtom.Open(
		pendingVillager.villagerId,
		pendingVillager.offerId,
		pendingVillager.villagerName
	)
end

return VillagerInteractionController
