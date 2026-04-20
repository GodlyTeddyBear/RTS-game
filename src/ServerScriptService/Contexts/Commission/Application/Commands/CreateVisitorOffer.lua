--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionTierConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionTierConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Try, Ensure, fromNilable = Result.Ok, Result.Try, Result.Ensure, Result.fromNilable

local CreateVisitorOffer = {}
CreateVisitorOffer.__index = CreateVisitorOffer

function CreateVisitorOffer.new()
	return setmetatable({}, CreateVisitorOffer)
end

function CreateVisitorOffer:Init(registry: any)
	self.CommissionGenerator = registry:Get("CommissionGenerator")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

function CreateVisitorOffer:Execute(playerOrUserId: Player | number, villagerId: string): Result.Result<any>
	local player = self:_ResolvePlayer(playerOrUserId)
	Ensure(player, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)
	Ensure(villagerId ~= "", "InvalidInput", "Invalid villager ID")

	local userId = player.UserId
	local state = Try(fromNilable(
		self.CommissionSyncService:GetCommissionStateReadOnly(userId),
		"PlayerNotFound",
		Errors.PLAYER_NOT_FOUND,
		{ userId = userId }
	))

	Ensure(
		not self.CommissionSyncService:HasPendingVisitorOffer(userId),
		"VisitorOfferAlreadyPending",
		Errors.VISITOR_OFFER_ALREADY_PENDING,
		{ userId = userId, villagerId = villagerId }
	)

	local tierConfig = Try(fromNilable(
		CommissionTierConfig[state.CurrentTier],
		"InvalidTier",
		"Invalid tier configuration",
		{ tier = state.CurrentTier }
	))

	local offer = Try(fromNilable(
		self.CommissionGenerator:GenerateVisitorOffer(state.CurrentTier, state.Active, villagerId, userId),
		"NoVisitorOfferAvailable",
		Errors.COMMISSION_NOT_FOUND,
		{ userId = userId, villagerId = villagerId, tier = state.CurrentTier, boardSize = tierConfig.BoardSize }
	))

	self.CommissionSyncService:AddToBoard(userId, offer)
	self:_PersistAndHydrate(player, userId)

	return Ok(offer)
end

function CreateVisitorOffer:_ResolvePlayer(playerOrUserId: Player | number): Player?
	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		return playerOrUserId
	end

	if type(playerOrUserId) == "number" then
		return Players:GetPlayerByUserId(playerOrUserId)
	end

	return nil
end

function CreateVisitorOffer:_PersistAndHydrate(player: Player, userId: number)
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	self.CommissionSyncService:HydratePlayer(player)
end

return CreateVisitorOffer
