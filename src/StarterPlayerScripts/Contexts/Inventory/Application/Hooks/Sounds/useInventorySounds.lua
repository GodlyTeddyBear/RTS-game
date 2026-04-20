--!strict
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

--[=[
	@interface TInventorySounds
	@within useInventorySounds
	.onTabSwitch (tabName: string) -> () -- Play tab switch sound
	.onBack () -> () -- Play menu close sound
]=]
export type TInventorySounds = {
	onTabSwitch: (tabName: string) -> (),
	onBack: () -> (),
}

--[=[
	@function useInventorySounds
	@within useInventorySounds
	Sound side-effects for the inventory feature. Wraps useSoundActions so the
	screen controller never calls useSoundActions directly.
	@return TInventorySounds
]=]
local function useInventorySounds(): TInventorySounds
	local soundActions = useSoundActions()
	return {
		onTabSwitch = function(tabName: string)
			soundActions.playTabSwitch(tabName)
		end,
		onBack = function()
			soundActions.playMenuClose("Inventory")
		end,
	}
end

return useInventorySounds
