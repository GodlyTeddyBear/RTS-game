--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useInventorySlotCellController = require(script.Parent.Parent.Parent.Application.Hooks.useInventorySlotCellController)
local InventorySlotCellView = require(script.Parent.InventorySlotCellView)

local InventorySlotViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.InventorySlotViewModel)

--[=[
	@interface TInventorySlotCellProps
	@within InventorySlotCell
	.Item InventorySlotViewModel -- Slot data
	.OnSelect ((item: InventorySlotViewModel) -> ())? -- Selection handler
	.IsSelected boolean? -- Current selection state
	.LayoutOrder number? -- Grid layout order
]=]
export type TInventorySlotCellProps = {
	Item: InventorySlotViewModel.TInventorySlotViewModel,
	OnSelect: ((item: InventorySlotViewModel.TInventorySlotViewModel) -> ())?,
	IsSelected: boolean?,
	LayoutOrder: number?,
}

--[=[
	@function InventorySlotCell
	@within InventorySlotCell
	Container component wiring slot controller data to view.
	@param props TInventorySlotCellProps
	@return React.ReactElement?
]=]
local function InventorySlotCell(props: TInventorySlotCellProps)
	local controller = useInventorySlotCellController(props.Item, props.OnSelect, props.IsSelected)

	return e(InventorySlotCellView, {
		Item = props.Item,
		LayoutOrder = props.LayoutOrder,
		ButtonRef = controller.buttonRef,
		OnMouseEnter = controller.onMouseEnter,
		OnMouseLeave = controller.onMouseLeave,
		OnActivated = controller.onActivated,
		IsSelected = controller.isSelected,
		DecoreStroke = controller.decoreStroke,
		ItemIcon = controller.itemIcon,
		NameAbbr = controller.nameAbbr,
		ShowQuantity = controller.showQuantity,
	})
end

return InventorySlotCell
