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
	local inventoryEvents = Events.Inventory
	local commissionEvents = Events.Commission

	return {
		playButtonClick = function(variant: string?)
			if not uiEvents then
				return
			end
			GameEvents.Bus:Emit(uiEvents.ButtonClicked, variant or "primary")
		end,

		playMenuOpen = function(menuName: string)
			if not uiEvents then
				return
			end
			GameEvents.Bus:Emit(uiEvents.MenuOpened, menuName)
		end,

		playMenuClose = function(menuName: string)
			if not uiEvents then
				return
			end
			GameEvents.Bus:Emit(uiEvents.MenuClosed, menuName)
		end,

		playTabSwitch = function(tabName: string)
			if not uiEvents then
				return
			end
			GameEvents.Bus:Emit(uiEvents.TabSwitched, tabName)
		end,

		playError = function(errorType: string?)
			if not uiEvents then
				return
			end
			GameEvents.Bus:Emit(uiEvents.ErrorOccurred, errorType or "generic")
		end,

		playPurchase = function()
			if not inventoryEvents then
				return
			end
			GameEvents.Bus:Emit(inventoryEvents.ItemBought)
		end,

		playSell = function()
			if not inventoryEvents then
				return
			end
			GameEvents.Bus:Emit(inventoryEvents.ItemSoldClient)
		end,

		playCommissionAccept = function()
			if not commissionEvents then
				return
			end
			GameEvents.Bus:Emit(commissionEvents.CommissionAcceptedClient)
		end,

		playCommissionDeliver = function()
			if not commissionEvents then
				return
			end
			GameEvents.Bus:Emit(commissionEvents.CommissionDeliveredClient)
		end,
	}
end

return useSoundActions
