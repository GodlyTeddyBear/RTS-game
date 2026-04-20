--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local VillagerInteractionAtom = require(script.Parent.Parent.Parent.Infrastructure.VillagerInteractionAtom)

local function _StartFarewellDialogue(npcId: string)
	Knit.GetController("DialogueController"):StartDialogueSession(npcId)
end

local function useVillagerInteractionActions()
	local function close()
		VillagerInteractionAtom.Close()
	end

	local function acceptOffer(offerId: string)
		return Knit.GetService("CommissionContext"):AcceptVisitorOffer(offerId)
			:andThen(function()
				VillagerInteractionAtom.Close()
				_StartFarewellDialogue("VillagerFarewellAccepted")
			end)
			:catch(function(err)
				warn("[useVillagerInteractionActions:acceptOffer]", tostring(err))
				VillagerInteractionAtom.Close()
			end)
	end

	local function declineOffer(offerId: string)
		return Knit.GetService("CommissionContext"):DeclineVisitorOffer(offerId)
			:andThen(function()
				VillagerInteractionAtom.Close()
				_StartFarewellDialogue("VillagerFarewellDeclined")
			end)
			:catch(function(err)
				warn("[useVillagerInteractionActions:declineOffer]", tostring(err))
				VillagerInteractionAtom.Close()
			end)
	end

	return {
		close = close,
		acceptOffer = acceptOffer,
		declineOffer = declineOffer,
	}
end

return useVillagerInteractionActions
