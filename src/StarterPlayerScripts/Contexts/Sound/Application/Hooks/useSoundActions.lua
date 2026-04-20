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
	return {
		playButtonClick = function(variant: string?)
			GameEvents.Bus:Emit(Events.UI.ButtonClicked, variant or "primary")
		end,

		playMenuOpen = function(menuName: string)
			GameEvents.Bus:Emit(Events.UI.MenuOpened, menuName)
		end,

		playMenuClose = function(menuName: string)
			GameEvents.Bus:Emit(Events.UI.MenuClosed, menuName)
		end,

		playTabSwitch = function(tabName: string)
			GameEvents.Bus:Emit(Events.UI.TabSwitched, tabName)
		end,

		playError = function(errorType: string?)
			GameEvents.Bus:Emit(Events.UI.ErrorOccurred, errorType or "generic")
		end,

		playPurchase = function()
			GameEvents.Bus:Emit(Events.Inventory.ItemBought)
		end,

		playSell = function()
			GameEvents.Bus:Emit(Events.Inventory.ItemSoldClient)
		end,

		playCommissionAccept = function()
			GameEvents.Bus:Emit(Events.Commission.CommissionAcceptedClient)
		end,

		playCommissionDeliver = function()
			GameEvents.Bus:Emit(Events.Commission.CommissionDeliveredClient)
		end,
	}
end

return useSoundActions
