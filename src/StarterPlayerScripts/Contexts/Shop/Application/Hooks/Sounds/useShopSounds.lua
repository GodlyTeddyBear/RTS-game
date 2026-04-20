--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local useSoundActions = require(script.Parent.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

--[=[
	@interface TShopSounds
	@within useShopSounds
	Sound callbacks for all Shop user interactions.
	.onTabSwitch (tab: string) -> () -- Play tab switch sound for a given tab or category key
	.onBuy () -> () -- Play button click + purchase sound
	.onSell () -> () -- Play button click + sell sound
	.onBack () -> () -- Play menu close sound
]=]
export type TShopSounds = {
	onTabSwitch: (tab: string) -> (),
	onBuy: () -> (),
	onSell: () -> (),
	onBack: () -> (),
}

--[=[
	@function useShopSounds
	@within useShopSounds
	Provides stable sound callbacks for Shop interactions. Delegates to useSoundActions.
	@return TShopSounds
]=]
local function useShopSounds(): TShopSounds
	local soundActions = useSoundActions()

	local function onTabSwitch(tab: string)
		soundActions.playTabSwitch(tab)
	end

	local function onBuy()
		soundActions.playButtonClick("buy")
		soundActions.playPurchase()
	end

	local function onSell()
		soundActions.playButtonClick("sell")
		soundActions.playSell()
	end

	local function onBack()
		soundActions.playMenuClose("Shop")
	end

	return {
		onTabSwitch = onTabSwitch,
		onBuy = onBuy,
		onSell = onSell,
		onBack = onBack,
	}
end

return useShopSounds
