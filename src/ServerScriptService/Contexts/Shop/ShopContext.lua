--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.GoldSyncServer)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Catch = Result.Catch
local Events = GameEvents.Events

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

-- Domain Policies
local BuyPolicy = require(script.Parent.ShopDomain.Policies.BuyPolicy)
local SellPolicy = require(script.Parent.ShopDomain.Policies.SellPolicy)

-- Persistence Infrastructure
local GoldSyncService = require(script.Parent.Infrastructure.Persistence.GoldSyncService)

-- Application Services
local BuyItem = require(script.Parent.Application.Commands.BuyItem)
local SellItem = require(script.Parent.Application.Commands.SellItem)

--[=[
	@class ShopContext
	Knit service managing shop operations: item purchases, sales, and gold synchronization.
	@server
]=]
local ShopContext = Knit.CreateService({
	Name = "ShopContext",
	Client = {},
})

--[=[
	Initialize the Shop context with registry, policies, and services.
	@within ShopContext
	@yields
]=]
function ShopContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Raw value registrations
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("ProfileManager", ProfileManager)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("ShopContext")

	-- Domain Policies
	registry:Register("BuyPolicy", BuyPolicy.new(), "Domain")
	registry:Register("SellPolicy", SellPolicy.new(), "Domain")

	-- Infrastructure Services
	registry:Register("GoldSyncService", GoldSyncService.new(), "Infrastructure")

	-- Application Services
	registry:Register("BuyItem", BuyItem.new(), "Application")
	registry:Register("SellItem", SellItem.new(), "Application")

	registry:InitAll()

	-- Cache refs needed by context handlers
	self.GoldSyncService = registry:Get("GoldSyncService")
end

--[=[
	Start the Shop context, resolve cross-context dependencies, and subscribe to lifecycle events.
	@within ShopContext
	@yields
]=]
function ShopContext:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies (must happen after all services init)
	local InventoryContext = Knit.GetService("InventoryContext")
	self.InventoryContext = InventoryContext
	registry:Register("InventoryContext", InventoryContext)
	registry:Register("UnlockContext", Knit.GetService("UnlockContext"))
	local UpgradeContext = Knit.GetService("UpgradeContext")
	self.UpgradeContext = UpgradeContext
	registry:Register("UpgradeContext", UpgradeContext)

	registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Cache refs for event handlers
	self.BuyItem = registry:Get("BuyItem")
	self.SellItem = registry:Get("SellItem")

	-- Subscribe to lifecycle events
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadGoldOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "ShopContext")
			end)
			:catch(function(err)
				warn("[ShopContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		self.GoldSyncService:RemovePlayerGold(player.UserId)
	end)

	print("ShopContext started")
end

-- Load player's gold from profile and sync to client.
function ShopContext:_LoadGoldOnPlayerJoin(player: Player)
	local data = ProfileManager:GetData(player)
	local gold = data and data.Gold or 0
	self.GoldSyncService:LoadPlayerGold(player.UserId, gold)
	self.GoldSyncService:HydratePlayer(player)
end

--[=[
	Buy an item from the shop.
	@within ShopContext
	@param player Player -- The player making the purchase
	@param itemId string -- The item to purchase
	@param quantity number -- How many to purchase
	@return Result<any> -- Purchase result with item, quantity, cost, and remaining gold
]=]
function ShopContext.Client:BuyItem(player: Player, itemId: string, quantity: number)
	local userId = player.UserId
	return Catch(function()
		return self.Server.BuyItem:Execute(player, userId, itemId, quantity)
	end, "Shop.Client:BuyItem")
end

--[=[
	Sell an item from the player's inventory.
	@within ShopContext
	@param player Player -- The player selling the item
	@param slotIndex number -- The inventory slot index
	@param quantity number -- How many to sell
	@return Result<any> -- Sale result with item, quantity, revenue, and new gold
]=]
function ShopContext.Client:SellItem(player: Player, slotIndex: number, quantity: number)
	local userId = player.UserId
	return Catch(function()
		return self.Server.SellItem:Execute(player, userId, slotIndex, quantity)
	end, "Shop.Client:SellItem")
end

--[=[
	Request current gold state and hydrate client.
	@within ShopContext
	@param player Player -- The player requesting gold state
	@return boolean -- Always returns true on success
	@yields
]=]
function ShopContext.Client:RequestGoldState(player: Player): boolean
	local userId = player.UserId

	-- If gold not yet in atom, wait for player ready
	if not self.Server.GoldSyncService:IsPlayerLoaded(userId) then
		if not PlayerLifecycleManager:IsPlayerReady(player) then
			GameEvents.Bus:Wait(Events.Persistence.PlayerReady)
		end
		local data = ProfileManager:GetData(player)
		local gold = data and data.Gold or 0
		self.Server.GoldSyncService:LoadPlayerGold(userId, gold)
	end

	self.Server.GoldSyncService:HydratePlayer(player)
	return true
end

--[=[
	Get a player's current gold amount (server-to-server API).
	@within ShopContext
	@param userId number -- The player's user ID
	@return Result<number> -- The player's current gold
]=]
function ShopContext:GetPlayerGold(userId: number): Result.Result<number>
	return Catch(function()
		return self.GoldSyncService:GetGoldReadOnly(userId)
	end, "Shop:GetPlayerGold")
end

--[=[
	Deduct gold from a player (server-to-server API).
	@within ShopContext
	@param player Player -- The player
	@param userId number -- The player's user ID
	@param amount number -- The amount to deduct
	@return Result<any> -- The new gold amount
]=]
function ShopContext:DeductGold(player: Player, userId: number, amount: number): Result.Result<any>
	return Catch(function()
		return self.GoldSyncService:RemoveGold(player, userId, amount)
	end, "Shop:DeductGold")
end

--[=[
	Add gold to a player (server-to-server API).
	@within ShopContext
	@param player Player -- The player
	@param userId number -- The player's user ID
	@param amount number -- The amount to add
	@return Result<any> -- The new gold amount
]=]
function ShopContext:AddGold(player: Player, userId: number, amount: number): Result.Result<any>
	return Catch(function()
		local mult = self.UpgradeContext and self.UpgradeContext:GetGoldMultiplier(userId) or 1
		local adjusted = math.floor(amount * mult)
		return self.GoldSyncService:AddGold(player, userId, adjusted)
	end, "Shop:AddGold")
end

WrapContext(ShopContext, "ShopContext")

return ShopContext
