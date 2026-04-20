--!strict

--[=[
	@class VillagerSpecs
	Specifications for validating villager targeting and lot eligibility.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@interface TTargetLotCandidate
	@within VillagerSpecs
	.PlayerLoaded boolean -- Player must be loaded in the game
	.HasShopMarkers boolean -- Lot must have entrance, wait point, and exit markers
	.HasNoPendingOffer boolean -- No pending commission offer at the lot
]=]
export type TTargetLotCandidate = {
	PlayerLoaded: boolean,
	HasShopMarkers: boolean,
	HasNoPendingOffer: boolean,
}

local PlayerLoaded = Spec.new("PlayerNotLoaded", Errors.NO_ELIGIBLE_LOT,
	function(candidate: TTargetLotCandidate)
		return candidate.PlayerLoaded
	end
)

local HasShopMarkers = Spec.new("MissingShopMarkers", Errors.NO_ELIGIBLE_LOT,
	function(candidate: TTargetLotCandidate)
		return candidate.HasShopMarkers
	end
)

local HasNoPendingOffer = Spec.new("PendingOfferExists", Errors.NO_ELIGIBLE_LOT,
	function(candidate: TTargetLotCandidate)
		return candidate.HasNoPendingOffer
	end
)

return table.freeze({
	CanTargetLot = Spec.All({ PlayerLoaded, HasShopMarkers, HasNoPendingOffer }),
})
