--!strict

--[[
	useSoundActions - Write hook for triggering sounds from React components.

	Returns functions that fire GameEvents signals on the client.
	The SoundController listens to these events and plays the appropriate sounds.

	This is a write hook: it does NOT subscribe to any state (no re-renders).

	Usage:
		local soundActions = useSoundActions()
		soundActions.playButtonClick("primary")
		soundActions.playMenuOpen("Shop")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local function useSoundActions()
	local uiEvents = Events.UI

	return {
		playButtonClick = function(variant: string?)
			GameEvents.Bus:Emit(uiEvents.ButtonClicked, variant or "primary")
		end,

		playMenuOpen = function(menuName: string)
			GameEvents.Bus:Emit(uiEvents.MenuOpened, menuName)
		end,

		playMenuClose = function(menuName: string)
			GameEvents.Bus:Emit(uiEvents.MenuClosed, menuName)
		end,

		playTabSwitch = function(tabName: string)
			GameEvents.Bus:Emit(uiEvents.TabSwitched, tabName)
		end,

		playError = function(errorType: string?)
			GameEvents.Bus:Emit(uiEvents.ErrorOccurred, errorType or "generic")
		end,
	}
end

return useSoundActions
