--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local Knit = require(ReplicatedStorage.Packages.Knit)

local useVillagerInteractionState = require(script.Parent.useVillagerInteractionState)
local useVillagerInteractionActions = require(script.Parent.useVillagerInteractionActions)
local VillagerOfferViewModel = require(script.Parent.Parent.ViewModels.VillagerOfferViewModel)

local useAtom = ReactCharm.useAtom
local commissionsAtom = nil

export type TVillagerOfferController = {
	isOpen: boolean,
	viewModel: VillagerOfferViewModel.TVillagerOfferVM?,
	onClose: () -> (),
	onAccept: () -> (),
	onDecline: () -> (),
}

local function _FindVisitorOffer(board: { any }, offerId: string?): any?
	if not offerId then
		return nil
	end

	for _, offer in ipairs(board) do
		if offer.Id == offerId and offer.Source == "Visitor" then
			return offer
		end
	end

	return nil
end

local function useVillagerOfferController(): TVillagerOfferController
	local interaction = useVillagerInteractionState()
	if commissionsAtom == nil then
		commissionsAtom = Knit.GetController("CommissionController"):GetCommissionsAtom()
	end
	local commissionState = useAtom(commissionsAtom)
	local actions = useVillagerInteractionActions()

	local offerId = interaction.offerId
	local villagerName = interaction.villagerName or "Villager"
	local board = if commissionState then commissionState.Board else {}
	local active = if commissionState then commissionState.Active else {}

	local visitorOffer = React.useMemo(function()
		return _FindVisitorOffer(board, offerId)
	end, { board, offerId } :: { any })

	local viewModel = React.useMemo(function()
		if not visitorOffer then
			return nil
		end
		return VillagerOfferViewModel.fromOffer(visitorOffer, villagerName, #active)
	end, { visitorOffer, villagerName, active } :: { any })

	React.useEffect(function()
		if interaction.open and commissionState ~= nil and not visitorOffer then
			actions.close()
		end
	end, { interaction.open, commissionState, visitorOffer } :: { any })

	local onAccept = React.useCallback(function()
		if offerId then
			actions.acceptOffer(offerId)
		end
	end, { offerId } :: { any })

	local onDecline = React.useCallback(function()
		if offerId then
			actions.declineOffer(offerId)
		end
	end, { offerId } :: { any })

	return {
		isOpen = interaction.open and viewModel ~= nil,
		viewModel = viewModel,
		onClose = actions.close,
		onAccept = onAccept,
		onDecline = onDecline,
	}
end

return useVillagerOfferController
