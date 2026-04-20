--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Try, Ensure, fromNilable = Result.Ok, Result.Try, Result.Ensure, Result.fromNilable

local DeclineVisitorOffer = {}
DeclineVisitorOffer.__index = DeclineVisitorOffer

function DeclineVisitorOffer.new()
	return setmetatable({}, DeclineVisitorOffer)
end

function DeclineVisitorOffer:Init(registry: any)
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

function DeclineVisitorOffer:Execute(player: Player, offerId: string): Result.Result<boolean>
	Ensure(player and offerId ~= "", "InvalidInput", Errors.INVALID_COMMISSION_ID)

	local userId = player.UserId
	local state = Try(fromNilable(
		self.CommissionSyncService:GetCommissionStateReadOnly(userId),
		"PlayerNotFound",
		Errors.PLAYER_NOT_FOUND,
		{ userId = userId }
	))

	Ensure(self:_FindVisitorOffer(state.Board, offerId), "VisitorOfferNotFound", Errors.VISITOR_OFFER_NOT_FOUND, {
		userId = userId,
		offerId = offerId,
	})

	self.CommissionSyncService:RemoveFromBoard(userId, offerId)
	self:_PersistAndHydrate(player, userId)

	return Ok(true)
end

function DeclineVisitorOffer:_FindVisitorOffer(board: { any }, offerId: string): any?
	for _, commission in ipairs(board) do
		if commission.Id == offerId and commission.Source == "Visitor" then
			return commission
		end
	end

	return nil
end

function DeclineVisitorOffer:_PersistAndHydrate(player: Player, userId: number)
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	self.CommissionSyncService:HydratePlayer(player)
end

return DeclineVisitorOffer
