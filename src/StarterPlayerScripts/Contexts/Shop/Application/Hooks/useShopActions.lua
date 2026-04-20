--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@interface TShopActionsHook
	@within ShopController
	.buyItem (itemId: string, quantity: number) -> () -- Purchase an item; refetches gold after completion
	.sellItem (slotIndex: number, quantity: number) -> () -- Sell an item from inventory; refetches gold after completion
]=]

--[=[
	@function useShopActions
	@within ShopController
	Expose shop mutation actions without subscribing to any atom. Component will not re-render from this hook.
	@return TShopActionsHook -- Buy and sell action functions
]=]
local function useShopActions()
	local shopController = Knit.GetController("ShopController")

	local function buyItem(itemId: string, quantity: number)
		if not shopController then
			warn("useShopActions: ShopController not available")
			return
		end
		shopController:BuyItem(itemId, quantity)
			:andThen(function()
				shopController:RequestGoldState()
			end)
	end

	local function sellItem(slotIndex: number, quantity: number)
		if not shopController then
			warn("useShopActions: ShopController not available")
			return
		end
		shopController:SellItem(slotIndex, quantity)
			:andThen(function()
				shopController:RequestGoldState()
			end)
	end

	return {
		buyItem = buyItem,
		sellItem = sellItem,
	}
end

return useShopActions
