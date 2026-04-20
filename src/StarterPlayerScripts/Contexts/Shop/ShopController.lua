--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
-- Infrastructure
local GoldSyncClientModule = require(script.Parent.Infrastructure.GoldSyncClient)

--[=[
	@class ShopController
	Manages the Shop context on the client, including gold state synchronization and transaction actions.
	@client
]=]
local ShopController = Knit.CreateController({
	Name = "ShopController",
})

function ShopController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	-- Create gold sync client with Blink transport
	self.GoldSyncService = GoldSyncClientModule.new()
	registry:Register("GoldSyncService", self.GoldSyncService, "Infrastructure")

	registry:InitAll()
end

function ShopController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local ShopContext = Knit.GetService("ShopContext")
	registry:Register("ShopContext", ShopContext)

	self.ShopContext = ShopContext

	registry:StartOrdered({ "Infrastructure" })

	-- Request initial gold state with a small delay
	task.delay(0.3, function()
		self:RequestGoldState()
	end)
end

--[=[
	Get the gold atom for UI components.
	@within ShopController
	@return Atom -- The gold atom reflecting current gold balance
]=]
function ShopController:GetGoldAtom()
	return self.GoldSyncService:GetGoldAtom()
end

--[=[
	Request gold state hydration from the server.
	@within ShopController
	@return Result -- Succeeds when gold state is refreshed
	@yields
]=]
function ShopController:RequestGoldState()
	return self.ShopContext:RequestGoldState()
		:catch(function(err)
			warn("[ShopController:RequestGoldState]", err.type, err.message)
		end)
end

--[=[
	Buy an item from the shop.
	@within ShopController
	@param itemId string -- ID of the item to purchase
	@param quantity number -- How many to buy
	@return Result -- Succeeds if purchase completes
	@yields
]=]
function ShopController:BuyItem(itemId: string, quantity: number)
	return self.ShopContext:BuyItem(itemId, quantity)
		:catch(function(err)
			warn("[ShopController:BuyItem]", err.type, err.message)
		end)
end

--[=[
	Sell an item from the player's inventory.
	@within ShopController
	@param slotIndex number -- Inventory slot to sell from
	@param quantity number -- How many to sell
	@return Result -- Succeeds if sale completes
	@yields
]=]
function ShopController:SellItem(slotIndex: number, quantity: number)
	return self.ShopContext:SellItem(slotIndex, quantity)
		:catch(function(err)
			warn("[ShopController:SellItem]", err.type, err.message)
		end)
end

return ShopController
