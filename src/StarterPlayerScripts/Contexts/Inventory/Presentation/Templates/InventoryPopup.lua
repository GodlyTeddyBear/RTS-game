--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useInventoryResources = require(script.Parent.Parent.Parent.Application.Hooks.useInventoryResources)
local useInventoryState = require(script.Parent.Parent.Parent.Application.Hooks.useInventoryState)
local InventoryViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.InventoryViewModel)
local InventoryPanel = require(script.Parent.Parent.Organisms.InventoryPanel)

export type TInventoryPopupProps = {
	onClose: () -> (),
}

local function InventoryPopup(props: TInventoryPopupProps)
	local inventoryState = useInventoryState()
	local wallet = useInventoryResources()

	local viewModel = React.useMemo(function()
		return InventoryViewModel.fromState(inventoryState, wallet)
	end, { inventoryState, wallet })

	return e(InventoryPanel, {
		viewModel = viewModel,
		onClose = props.onClose,
	})
end

return InventoryPopup
