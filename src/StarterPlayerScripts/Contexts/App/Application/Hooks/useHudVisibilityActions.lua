--!strict
--[=[
	@class useHudVisibilityActions
	React hook that returns imperative actions for global App HUD visibility.
	@client
]=]
local hudVisibilityAtom = require(script.Parent.Parent.Parent.Infrastructure.HudVisibilityAtom)

export type THudVisibilityActions = {
	setGameHudEnabled: (enabled: boolean, reason: string?) -> (),
}

local function useHudVisibilityActions(): THudVisibilityActions
	return {
		setGameHudEnabled = function(enabled: boolean, reason: string?)
			hudVisibilityAtom({
				IsGameHudEnabled = enabled,
				Reason = if enabled then nil else reason,
			})
		end,
	}
end

return useHudVisibilityActions
