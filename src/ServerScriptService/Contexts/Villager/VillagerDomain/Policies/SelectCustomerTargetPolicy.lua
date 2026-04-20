--!strict

--[=[
	@class SelectCustomerTargetPolicy
	Selects eligible player lots for incoming customer villagers to visit.
	@server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local VillagerSpecs = require(script.Parent.Parent.Specs.VillagerSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Err = Result.Ok, Result.Err

--[=[
	@interface TCustomerTarget
	@within SelectCustomerTargetPolicy
	.UserId number -- Target player's user ID
	.Entrance BasePart -- Entry point for customer to walk from
	.WaitPoint BasePart -- Location where customer waits for offer
	.ExitPoint BasePart -- Exit point when departing the lot
]=]
export type TCustomerTarget = {
	UserId: number,
	Entrance: BasePart,
	WaitPoint: BasePart,
	ExitPoint: BasePart,
}

local SelectCustomerTargetPolicy = {}
SelectCustomerTargetPolicy.__index = SelectCustomerTargetPolicy

function SelectCustomerTargetPolicy.new()
	return setmetatable({}, SelectCustomerTargetPolicy)
end

function SelectCustomerTargetPolicy:Init(registry: any)
	self.RouteDiscoveryService = registry:Get("VillagerRouteDiscoveryService")
end

function SelectCustomerTargetPolicy:Start()
	local Knit = require(ReplicatedStorage.Packages.Knit)
	self.CommissionContext = Knit.GetService("CommissionContext")
end

--[=[
	Selects a random eligible lot for a customer to visit.
	@within SelectCustomerTargetPolicy
	@param excludedUserIds { [number]: boolean } -- User IDs to skip (already hosting customers)
	@return Result<TCustomerTarget> -- Target lot with entrance/wait/exit points or error
]=]
function SelectCustomerTargetPolicy:Check(excludedUserIds: { [number]: boolean }): Result.Result<TCustomerTarget>
	local markers = self.RouteDiscoveryService:GetEligibleShopMarkers(excludedUserIds)
	local shuffled = self:_Shuffle(markers)

	-- Evaluate each candidate lot against eligibility specs
	for _, markerSet in ipairs(shuffled) do
		local player = Players:GetPlayerByUserId(markerSet.UserId)
		local hasPendingOffer = self:_HasPendingVisitorOffer(markerSet.UserId)
		local candidate: VillagerSpecs.TTargetLotCandidate = {
			PlayerLoaded = player ~= nil,
			HasShopMarkers = markerSet.Entrance ~= nil and markerSet.WaitPoint ~= nil and markerSet.ExitPoint ~= nil,
			HasNoPendingOffer = not hasPendingOffer,
		}

		local specResult = VillagerSpecs.CanTargetLot:IsSatisfiedBy(candidate)
		if specResult.success then
			return Ok({
				UserId = markerSet.UserId,
				Entrance = markerSet.Entrance,
				WaitPoint = markerSet.WaitPoint,
				ExitPoint = markerSet.ExitPoint,
			})
		end
	end

	return Err("NoEligibleLot", Errors.NO_ELIGIBLE_LOT)
end

-- Checks if player has a pending visitor commission offer; guards against race if CommissionContext unavailable.
function SelectCustomerTargetPolicy:_HasPendingVisitorOffer(userId: number): boolean
	if not self.CommissionContext or not self.CommissionContext.CommissionSyncService then
		return false
	end

	return self.CommissionContext.CommissionSyncService:HasPendingVisitorOffer(userId)
end

-- Fisher-Yates shuffle to randomize lot order.
function SelectCustomerTargetPolicy:_Shuffle(items: { any }): { any }
	local shuffled = table.clone(items)
	for index = #shuffled, 2, -1 do
		local swapIndex = math.random(1, index)
		shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
	end
	return shuffled
end

return SelectCustomerTargetPolicy
