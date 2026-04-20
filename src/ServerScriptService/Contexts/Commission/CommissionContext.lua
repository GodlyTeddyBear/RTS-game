--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.CommissionSyncServer)
local CommissionRewardConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionRewardConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Catch = Result.Catch
local Err = Result.Err
local Ok = Result.Ok
local Events = GameEvents.Events

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

-- Domain Services
local CommissionGenerator = require(script.Parent.CommissionDomain.Services.CommissionGenerator)

-- Domain Policies
local AcceptPolicy = require(script.Parent.CommissionDomain.Policies.AcceptPolicy)
local DeliverPolicy = require(script.Parent.CommissionDomain.Policies.DeliverPolicy)
local AbandonPolicy = require(script.Parent.CommissionDomain.Policies.AbandonPolicy)
local UnlockTierPolicy = require(script.Parent.CommissionDomain.Policies.UnlockTierPolicy)

-- Persistence Infrastructure
local CommissionSyncService = require(script.Parent.Infrastructure.Persistence.CommissionSyncService)
local CommissionPersistenceService = require(script.Parent.Infrastructure.Persistence.CommissionPersistenceService)

-- Application Services
local GenerateBoard = require(script.Parent.Application.Commands.GenerateBoard)
local AcceptCommission = require(script.Parent.Application.Commands.AcceptCommission)
local DeliverCommission = require(script.Parent.Application.Commands.DeliverCommission)
local AbandonCommission = require(script.Parent.Application.Commands.AbandonCommission)
local RefreshBoard = require(script.Parent.Application.Commands.RefreshBoard)
local UnlockTier = require(script.Parent.Application.Commands.UnlockTier)
local CreateVisitorOffer = require(script.Parent.Application.Commands.CreateVisitorOffer)
local DeclineVisitorOffer = require(script.Parent.Application.Commands.DeclineVisitorOffer)

local REFRESH_CHECK_INTERVAL = 60 -- Check for refreshes every 60 seconds

--[=[
	@class CommissionContext
	Knit service that owns the commission system lifecycle, cross-context API, and client remotes.
	@server
]=]
local CommissionContext = Knit.CreateService({
	Name = "CommissionContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function CommissionContext:KnitInit()
	-- Build the context registry
	local registry = Registry.new("Server")

	-- Register raw values
	registry:Register("ProfileManager", ProfileManager)
	registry:Register("BlinkServer", BlinkServer)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("CommissionContext")

	-- Domain Services
	registry:Register("CommissionGenerator", CommissionGenerator.new(), "Domain")

	-- Domain Policies
	registry:Register("AcceptPolicy", AcceptPolicy.new(), "Domain")
	registry:Register("DeliverPolicy", DeliverPolicy.new(), "Domain")
	registry:Register("AbandonPolicy", AbandonPolicy.new(), "Domain")
	registry:Register("UnlockTierPolicy", UnlockTierPolicy.new(), "Domain")

	-- Infrastructure Services
	registry:Register("CommissionSyncService", CommissionSyncService.new(), "Infrastructure")
	registry:Register("CommissionPersistenceService", CommissionPersistenceService.new(), "Infrastructure")

	-- Application Services
	registry:Register("GenerateBoardService", GenerateBoard.new(), "Application")
	registry:Register("AcceptCommissionService", AcceptCommission.new(), "Application")
	registry:Register("DeliverCommissionService", DeliverCommission.new(), "Application")
	registry:Register("AbandonCommissionService", AbandonCommission.new(), "Application")
	registry:Register("RefreshBoardService", RefreshBoard.new(), "Application")
	registry:Register("UnlockTierService", UnlockTier.new(), "Application")
	registry:Register("CreateVisitorOfferService", CreateVisitorOffer.new(), "Application")
	registry:Register("DeclineVisitorOfferService", DeclineVisitorOffer.new(), "Application")

	-- Wire all intra-context dependencies
	registry:InitAll()

	-- Cache refs on self
	self.CommissionGenerator = registry:Get("CommissionGenerator")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
	self.GenerateBoardService = registry:Get("GenerateBoardService")
	self.AcceptCommissionService = registry:Get("AcceptCommissionService")
	self.DeliverCommissionService = registry:Get("DeliverCommissionService")
	self.AbandonCommissionService = registry:Get("AbandonCommissionService")
	self.RefreshBoardService = registry:Get("RefreshBoardService")
	self.UnlockTierService = registry:Get("UnlockTierService")
	self.CreateVisitorOfferService = registry:Get("CreateVisitorOfferService")
	self.DeclineVisitorOfferService = registry:Get("DeclineVisitorOfferService")

	-- Store registry for StartAll in KnitStart
	self._registry = registry
end

function CommissionContext:KnitStart()
	-- Wire cross-context deps
	self._registry:Register("UnlockContext", Knit.GetService("UnlockContext"))

	-- StartAll wires remaining cross-context deps (DeliverCommission.Start pulls InventoryContext + ShopContext)
	self._registry:StartAll()

	-- Subscribe to lifecycle events
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadCommissionsOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "CommissionContext")
			end)
			:catch(function(err)
				warn("[CommissionContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		Catch(function()
			self:_CleanupOnPlayerLeave(player)
			return Ok(nil)
		end, "CommissionContext:ProfileSaving", function(err)
			warn("[CommissionContext:ProfileSaving]", err.type, err.message)
		end)
	end)

	-- Start refresh loop
	self:_StartRefreshLoop()

end

---
-- Player Data Loading
---

function CommissionContext:_LoadCommissionsOnPlayerJoin(player: Player)
	local userId = player.UserId

	-- Load from persistence or create default state
	local state = self:_LoadOrCreateState(player)

	-- Populate sync atom with player's commission state
	self.CommissionSyncService:LoadUserCommissions(userId, state)

	-- Generate or refresh board based on state
	self:_InitialiseBoard(player, userId, state)
end

function CommissionContext:_LoadOrCreateState(player: Player): any
	-- Load persisted data if available, otherwise initialize with defaults
	local commissionData = self.CommissionPersistenceService:LoadCommissionData(player)
	return commissionData or {
		Board = {},
		Active = {},
		Tokens = 0,
		CurrentTier = 1,
		LastRefreshTime = 0,
	}
end

function CommissionContext:_InitialiseBoard(player: Player, userId: number, state: any)
	local needsNewBoard = #state.Board == 0
	local needsRefresh = (os.time() - state.LastRefreshTime) >= CommissionRewardConfig.REFRESH_INTERVAL

	-- Generate new board for new players
	if needsNewBoard then
		self.GenerateBoardService:Execute(player, userId)
	-- Refresh expired entries if interval exceeded
	elseif needsRefresh then
		self.RefreshBoardService:Execute(player, userId)
	-- Sync existing board to client
	else
		self.CommissionSyncService:HydratePlayer(player)
	end
end

function CommissionContext:_CleanupOnPlayerLeave(player: Player)
	local userId = player.UserId

	-- Persist final state before cleanup
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if state then
		self.CommissionPersistenceService:SaveCommissionData(player, state)
	end

	-- Remove from sync atom
	self.CommissionSyncService:RemoveUserCommissions(userId)
end

---
-- Refresh Loop
---

function CommissionContext:_StartRefreshLoop()
	task.spawn(function()
		-- Check for stale boards on a regular interval
		while true do
			task.wait(REFRESH_CHECK_INTERVAL)
			self:_RefreshAllPlayers()
		end
	end)
end

function CommissionContext:_RefreshAllPlayers()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local isLoaded = self.CommissionSyncService:IsPlayerLoaded(userId)

		-- Spawn refresh asynchronously if player is loaded and board is stale
		if isLoaded and self.RefreshBoardService:NeedsRefresh(userId) then
			task.spawn(function()
				self.RefreshBoardService:Execute(player, userId)
			end)
		end
	end
end

---
-- Server-to-Server API
---

function CommissionContext:_RequireState(userId: number): any
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if not state then
		error(Err("CommissionStateNotLoaded", "Commission state not loaded", { userId = userId }))
	end
	return state
end

--[=[
	Return the commission token balance for a user.
	@within CommissionContext
	@param userId number -- The player's UserId
	@return Result<number> -- The current token balance
]=]
function CommissionContext:GetTokenBalance(userId: number): Result.Result<number>
	return Catch(function()
		local state: any = self:_RequireState(userId)
		return Ok(state.Tokens)
	end, "Commission:GetTokenBalance")
end

--[=[
	Add commission tokens to a user's balance.
	@within CommissionContext
	@param userId number -- The player's UserId
	@param amount number -- Number of tokens to add
	@return Result<boolean> -- `true` on success
]=]
function CommissionContext:AddTokens(userId: number, amount: number): Result.Result<boolean>
	return Catch(function()
		local state: any = self:_RequireState(userId)
		self.CommissionSyncService:SetTokens(userId, state.Tokens + amount)
		return Ok(true)
	end, "Commission:AddTokens")
end

--[=[
	Remove commission tokens from a user's balance, returning an error if insufficient.
	@within CommissionContext
	@param userId number -- The player's UserId
	@param amount number -- Number of tokens to remove
	@return Result<boolean> -- `true` on success, `Err` if balance is insufficient
]=]
function CommissionContext:RemoveTokens(userId: number, amount: number): Result.Result<boolean>
	return Catch(function()
		local state: any = self:_RequireState(userId)
		if state.Tokens < amount then
			return Err(
				"InsufficientTokens",
				"Insufficient tokens",
				{ userId = userId, required = amount, available = state.Tokens }
			)
		end
		self.CommissionSyncService:SetTokens(userId, state.Tokens - amount)
		return Ok(true)
	end, "Commission:RemoveTokens")
end

---
-- Server API Methods
---

--[=[
	Move a commission from the player's board to their active list.
	@within CommissionContext
	@param player Player -- The player accepting the commission
	@param commissionId string -- The ID of the commission to accept
	@return Result<any> -- `true` on success
]=]
function CommissionContext:AcceptCommission(player: Player, commissionId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.AcceptCommissionService:Execute(player, userId, commissionId)
	end, "Commission:AcceptCommission")
end

--[=[
	Deliver items for an active commission, granting rewards and removing it from the active list.
	@within CommissionContext
	@param player Player -- The player delivering the commission
	@param commissionId string -- The ID of the active commission to deliver
	@return Result<any> -- `true` on success
]=]
function CommissionContext:DeliverCommission(player: Player, commissionId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.DeliverCommissionService:Execute(player, userId, commissionId)
	end, "Commission:DeliverCommission")
end

--[=[
	Remove an active commission without penalty.
	@within CommissionContext
	@param player Player -- The player abandoning the commission
	@param commissionId string -- The ID of the active commission to abandon
	@return Result<any> -- `true` on success
]=]
function CommissionContext:AbandonCommission(player: Player, commissionId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.AbandonCommissionService:Execute(player, userId, commissionId)
	end, "Commission:AbandonCommission")
end

--[=[
	Spend tokens to unlock the next commission tier and regenerate the board.
	@within CommissionContext
	@param player Player -- The player unlocking the tier
	@return Result<any> -- `true` on success
]=]
function CommissionContext:UnlockTier(player: Player): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.UnlockTierService:Execute(player, userId)
	end, "Commission:UnlockTier")
end

--[=[
	Force a full board refresh for a player, replacing all existing entries.
	@within CommissionContext
	@param player Player -- The player whose board to refresh
	@return Result<any> -- `true` on success
]=]
function CommissionContext:RefreshBoard(player: Player): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.RefreshBoardService:ExecuteForce(player, userId)
	end, "Commission:RefreshBoard")
end

--[=[
	Create a visitor-originated commission offer for a loaded player.
	@within CommissionContext
	@param playerOrUserId Player | number -- Player instance or UserId receiving the offer
	@param villagerId string -- Runtime villager ID creating the offer
	@return Result<any> -- Created visitor offer
]=]
function CommissionContext:CreateVisitorOffer(playerOrUserId: Player | number, villagerId: string): Result.Result<any>
	return Catch(function()
		return self.CreateVisitorOfferService:Execute(playerOrUserId, villagerId)
	end, "Commission:CreateVisitorOffer")
end

--[=[
	Accept a visitor-originated offer. Uses the existing accept path so delivery stays compatible.
	@within CommissionContext
	@param player Player -- The player accepting the offer
	@param offerId string -- Visitor offer ID
	@return Result<any> -- `true` on success
]=]
function CommissionContext:AcceptVisitorOffer(player: Player, offerId: string): Result.Result<any>
	return self:AcceptCommission(player, offerId)
end

--[=[
	Decline a visitor-originated offer and remove it from the pending board list.
	@within CommissionContext
	@param player Player -- The player declining the offer
	@param offerId string -- Visitor offer ID
	@return Result<boolean> -- `true` on success
]=]
function CommissionContext:DeclineVisitorOffer(player: Player, offerId: string): Result.Result<boolean>
	return Catch(function()
		return self.DeclineVisitorOfferService:Execute(player, offerId)
	end, "Commission:DeclineVisitorOffer")
end

--[=[
	Ensure a player's commission state is loaded and push it to the client.
	@within CommissionContext
	@param player Player -- The requesting player
	@return Result<boolean> -- `true` once state is hydrated
]=]
function CommissionContext:RequestCommissionState(player: Player): Result.Result<boolean>
	return Catch(function()
		local userId = player.UserId

		if not self.CommissionSyncService:IsPlayerLoaded(userId) then
			if not PlayerLifecycleManager:IsPlayerReady(player) then
				GameEvents.Bus:Wait(Events.Persistence.PlayerReady)
			end
			local state = self:_LoadOrCreateState(player)
			self.CommissionSyncService:LoadUserCommissions(userId, state)
		end

		self.CommissionSyncService:HydratePlayer(player)
		return Ok(true)
	end, "Commission:RequestCommissionState")
end

---
-- Client API Methods
---

function CommissionContext.Client:AcceptCommission(player: Player, commissionId: string)
	return self.Server:AcceptCommission(player, commissionId)
end

function CommissionContext.Client:DeliverCommission(player: Player, commissionId: string)
	return self.Server:DeliverCommission(player, commissionId)
end

function CommissionContext.Client:AbandonCommission(player: Player, commissionId: string)
	return self.Server:AbandonCommission(player, commissionId)
end

function CommissionContext.Client:UnlockTier(player: Player)
	return self.Server:UnlockTier(player)
end

function CommissionContext.Client:RefreshBoard(player: Player)
	return self.Server:RefreshBoard(player)
end

function CommissionContext.Client:AcceptVisitorOffer(player: Player, offerId: string)
	return self.Server:AcceptVisitorOffer(player, offerId)
end

function CommissionContext.Client:DeclineVisitorOffer(player: Player, offerId: string)
	return self.Server:DeclineVisitorOffer(player, offerId)
end

function CommissionContext.Client:RequestCommissionState(player: Player)
	return self.Server:RequestCommissionState(player)
end

WrapContext(CommissionContext, "CommissionContext")

return CommissionContext
