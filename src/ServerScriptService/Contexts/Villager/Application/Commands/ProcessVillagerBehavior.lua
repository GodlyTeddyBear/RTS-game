--!strict

--[=[
	@class ProcessVillagerBehavior
	Command service that updates villager behavior states and handles state transitions each tick.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VillagerConfig = require(ReplicatedStorage.Contexts.Villager.Config.VillagerConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local ProcessVillagerBehavior = {}
ProcessVillagerBehavior.__index = ProcessVillagerBehavior

function ProcessVillagerBehavior.new()
	return setmetatable({}, ProcessVillagerBehavior)
end

function ProcessVillagerBehavior:Init(registry: any)
	self.EntityFactory = registry:Get("VillagerEntityFactory")
	self.GameObjectSyncService = registry:Get("VillagerGameObjectSyncService")
	self.PathingService = registry:Get("VillagerPathingService")
	self.RouteDiscoveryService = registry:Get("VillagerRouteDiscoveryService")
	self.SelectTargetPolicy = registry:Get("SelectCustomerTargetPolicy")
	self._lastTick = 0
end

function ProcessVillagerBehavior:Start()
	local Knit = require(ReplicatedStorage.Packages.Knit)
	self.CommissionContext = Knit.GetService("CommissionContext")
end

--[=[
	Processes one tick of villager behavior if interval has elapsed.
	@within ProcessVillagerBehavior
	@return Result<boolean> -- True if behavior was executed this tick, false if throttled
]=]
function ProcessVillagerBehavior:Execute(): Result.Result<boolean>
	local now = os.clock()
	-- Throttle behavior processing to configured tick interval
	if now - self._lastTick < VillagerConfig.BEHAVIOR_TICK_INTERVAL then
		return Ok(false)
	end
	self._lastTick = now

	-- Step 1: Process customer state machines (visiting lots)
	for _, entity in ipairs(self.EntityFactory:QueryCustomers()) do
		self:_ProcessCustomer(entity, now)
	end

	-- Step 2: Process merchants (static at locations)
	for _, entity in ipairs(self.EntityFactory:QueryMerchants()) do
		self:_ProcessMerchant(entity)
	end

	-- Step 3: Clean up entities marked for removal
	for _, entity in ipairs(self.EntityFactory:QueryCleanup()) do
		self:_CleanupEntity(entity)
	end

	return Ok(true)
end

-- Processes customer through their visit state machine (Spawning → WalkingToShop → WaitingForOffer → Departing).
function ProcessVillagerBehavior:_ProcessCustomer(entity: any, now: number)
	local visit = self.EntityFactory:GetVisit(entity)
	local route = self.EntityFactory:GetRoute(entity)
	if not visit or not route then
		return
	end

	-- Guard: Check for pathfinding timeout before processing state
	if self:_HasTimedOut(route, now) then
		self.EntityFactory:RequestCleanup(entity, "PathTimeout")
		return
	end

	-- State machine: route customer through visit lifecycle
	if visit.State == "Spawning" then
		self:_AssignCustomerTarget(entity)
	elseif visit.State == "WalkingToShop" then
		self:_HandleWalkingCustomer(entity, route)
	elseif visit.State == "WaitingForOffer" then
		self:_HandleWaitingCustomer(entity, visit, now)
	elseif visit.State == "Departing" then
		self:_HandleDepartingCustomer(entity, route)
	end
end

-- Transitions from Spawning to WalkingToShop by selecting eligible target lot and issuing path command.
function ProcessVillagerBehavior:_AssignCustomerTarget(entity: any)
	local excludedUserIds = self:_BuildExcludedTargets()
	local targetResult = self.SelectTargetPolicy:Check(excludedUserIds)
	-- If no eligible lot found, abandon visit and exit
	if not targetResult.success then
		self:_SendToExit(entity)
		return
	end

	-- Assign target lot details and move toward wait point
	local target = targetResult.value
	self.EntityFactory:SetVisitTarget(entity, target.UserId, target.Entrance, target.WaitPoint, target.ExitPoint)
	self.EntityFactory:SetVisitState(entity, "WalkingToShop")
	self.PathingService:MoveTo(entity, target.WaitPoint.Position)
end

-- Transitions from WalkingToShop to WaitingForOffer when customer reaches wait point.
function ProcessVillagerBehavior:_HandleWalkingCustomer(entity: any, route: any)
	if route.PathStatus == "Reached" then
		self:_CreateOffer(entity)
	elseif route.PathStatus == "Failed" then
		-- Pathfinding failed; exit the lot
		self:_SendToExit(entity)
	end
end

-- Creates a commission offer for the player and transitions to WaitingForOffer.
function ProcessVillagerBehavior:_CreateOffer(entity: any)
	local identity = self.EntityFactory:GetIdentity(entity)
	local visit = self.EntityFactory:GetVisit(entity)
	-- Guard: identity and target must exist; exit if not
	if not identity or not visit or not visit.TargetUserId then
		self:_SendToExit(entity)
		return
	end

	-- Request commission offer from CommissionContext; exit if creation fails
	local offerResult = self.CommissionContext:CreateVisitorOffer(visit.TargetUserId, identity.VillagerId)
	if not offerResult.success then
		self:_SendToExit(entity)
		return
	end

	-- Record offer ID and wait for player response
	self.EntityFactory:SetOfferId(entity, offerResult.value.Id)
	self.EntityFactory:SetVisitState(entity, "WaitingForOffer")
end

-- Exits if offer timeout elapsed or player accepted/rejected the offer.
function ProcessVillagerBehavior:_HandleWaitingCustomer(entity: any, visit: any, now: number)
	-- Check if customer has waited too long; exit if timeout reached
	if now - visit.LastStateChangedAt >= VillagerConfig.CUSTOMER_WAIT_SECONDS then
		self:_SendToExit(entity)
		return
	end

	-- Check if offer was accepted/rejected; exit if no longer pending
	if visit.TargetUserId and visit.OfferId and not self:_IsOfferStillPending(visit.TargetUserId, visit.OfferId) then
		self:_SendToExit(entity)
	end
end

-- Cleans up when customer reaches exit point.
function ProcessVillagerBehavior:_HandleDepartingCustomer(entity: any, route: any)
	if route.PathStatus == "Reached" or route.PathStatus == "Failed" then
		self.EntityFactory:RequestCleanup(entity, "Departed")
	end
end

-- Updates merchant model state; merchants are stationary and don't visit lots.
function ProcessVillagerBehavior:_ProcessMerchant(entity: any)
	local model = self.GameObjectSyncService:GetInstanceForEntity(entity)
	if not model then
		return
	end

	model:SetAttribute("VillagerState", "WaitingForOffer")
end

-- Transitions customer to Departing state by issuing path to exit point.
function ProcessVillagerBehavior:_SendToExit(entity: any)
	local exitCFrame = self.RouteDiscoveryService:GetRandomExitCFrame()
	-- If no exit point available, mark for cleanup immediately
	if not exitCFrame then
		self.EntityFactory:RequestCleanup(entity, "NoExit")
		return
	end

	self.EntityFactory:SetVisitState(entity, "Departing")
	self.PathingService:MoveTo(entity, exitCFrame.Position)
end

-- Builds set of user IDs with active customers to prevent multiple customers at same lot.
function ProcessVillagerBehavior:_BuildExcludedTargets(): { [number]: boolean }
	local excluded: { [number]: boolean } = {}
	for _, entity in ipairs(self.EntityFactory:QueryCustomers()) do
		local visit = self.EntityFactory:GetVisit(entity)
		-- Exclude users who have customers in Spawning/WalkingToShop/WaitingForOffer states
		if visit and visit.TargetUserId and visit.State ~= "Departing" and visit.State ~= "Complete" then
			excluded[visit.TargetUserId] = true
		end
	end
	return excluded
end

-- Checks if commission offer is still pending on player's board.
function ProcessVillagerBehavior:_IsOfferStillPending(userId: number, offerId: string): boolean
	local state = self.CommissionContext.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if not state then
		return false
	end

	for _, commission in ipairs(state.Board) do
		if commission.Id == offerId and commission.Source == "Visitor" then
			return true
		end
	end

	return false
end

-- Checks if pathfinding exceeded max duration; guards against infinite path attempts.
function ProcessVillagerBehavior:_HasTimedOut(route: any, now: number): boolean
	return route.PathStatus == "Moving" and now - route.PathStartedAt > VillagerConfig.PATH_TIMEOUT_SECONDS
end

-- Removes entity and model from world.
function ProcessVillagerBehavior:_CleanupEntity(entity: any)
	self.PathingService:Stop(entity)
	self.GameObjectSyncService:DeleteEntity(entity)
	self.EntityFactory:DeleteEntity(entity)
end

return ProcessVillagerBehavior
