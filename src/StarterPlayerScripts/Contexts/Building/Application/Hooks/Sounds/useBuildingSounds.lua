--!strict
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

--[=[
	@interface TBuildingSounds
	@within useBuildingSounds
	.onSlotSelect () -> () -- Play slot selection sound
	.onZoneSwitch (zoneName: string) -> () -- Play tab switch sound for zone
	.onBuildConfirm () -> () -- Play purchase sound after successful construction
	.onUpgrade () -> () -- Play button click for upgrade action
	.onClose () -> () -- Play button click for closing a panel
	.onError () -> () -- Play error sound
	.onBack () -> () -- Play menu close sound
	.onMenuOpen () -> () -- Play menu open sound
]=]
export type TBuildingSounds = {
	onSlotSelect: () -> (),
	onZoneSwitch: (zoneName: string) -> (),
	onBuildConfirm: () -> (),
	onUpgrade: () -> (),
	onClose: () -> (),
	onError: () -> (),
	onBack: () -> (),
	onMenuOpen: () -> (),
}

--[=[
	@function useBuildingSounds
	@within useBuildingSounds
	Sound side-effects for the building screen. Wraps useSoundActions so the
	screen controller never calls useSoundActions directly.
	@return TBuildingSounds
]=]
local function useBuildingSounds(): TBuildingSounds
	local soundActions = useSoundActions()

	return {
		onSlotSelect = function()
			soundActions.playButtonClick()
		end,
		onZoneSwitch = function(zoneName: string)
			soundActions.playTabSwitch(zoneName)
		end,
		onBuildConfirm = function()
			soundActions.playPurchase()
		end,
		onUpgrade = function()
			soundActions.playButtonClick()
		end,
		onClose = function()
			soundActions.playButtonClick()
		end,
		onError = function()
			soundActions.playError()
		end,
		onBack = function()
			soundActions.playMenuClose("Building")
		end,
		onMenuOpen = function()
			soundActions.playMenuOpen("Building")
		end,
	}
end

return useBuildingSounds
