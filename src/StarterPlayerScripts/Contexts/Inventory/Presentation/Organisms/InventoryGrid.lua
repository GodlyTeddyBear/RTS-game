--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)

local InventorySlotCell = require(script.Parent.InventorySlotCell)
local InventorySlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.InventorySlotViewModel)

--[=[
	@interface TInventoryGridProps
	@within InventoryGrid
	.GridItems { InventorySlotViewModel } -- Items to display in the grid
	.SelectedSlotIndex number? -- Currently selected slot index
	.ActiveTab string -- Active tab name (used for empty state messaging)
	.OnSelectItem (item: InventorySlotViewModel) -> () -- Selection callback
]=]
export type TInventoryGridProps = {
	GridItems: { InventorySlotViewModel.TInventorySlotViewModel },
	SelectedSlotIndex: number?,
	ActiveTab: string,
	OnSelectItem: (item: InventorySlotViewModel.TInventorySlotViewModel) -> (),
}

local COLUMNS = 5
local HORIZONTAL_PADDING = 0.02
local HORIZONTAL_GAP = 0.02
local VERTICAL_GAP = 0.02
local CELL_WIDTH = (1 - (HORIZONTAL_PADDING * 2) - (HORIZONTAL_GAP * (COLUMNS - 1))) / COLUMNS
local CELL_HEIGHT = CELL_WIDTH * 1.23274 -- Aspect ratio for item icons

-- Staggered entrance wrapper for individual slot cells
local function StaggeredInventorySlotCell(props: {
	Item: InventorySlotViewModel.TInventorySlotViewModel,
	IsSelected: boolean,
	OnSelect: (item: InventorySlotViewModel.TInventorySlotViewModel) -> (),
	LayoutOrder: number,
	Index: number,
})
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.Grid)
	if not isVisible then
		return nil
	end

	return e(InventorySlotCell, {
		Item = props.Item,
		IsSelected = props.IsSelected,
		OnSelect = props.OnSelect,
		LayoutOrder = props.LayoutOrder,
	})
end

--[=[
	@function InventoryGrid
	@within InventoryGrid
	Renders a scrollable grid of inventory slot cells with staggered entrance
	animations and an empty-state message when no items match the active tab.
	@param props TInventoryGridProps
	@return React.ReactElement
]=]
local function InventoryGrid(props: TInventoryGridProps)
	local children: { [string]: any } = {
		UIGridLayout = e("UIGridLayout", {
			CellSize = UDim2.fromScale(CELL_WIDTH, CELL_HEIGHT),
			CellPadding = UDim2.fromScale(HORIZONTAL_GAP, VERTICAL_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			FillDirectionMaxCells = COLUMNS,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(HORIZONTAL_PADDING, 0),
			PaddingRight = UDim.new(HORIZONTAL_PADDING, 0),
			PaddingTop = UDim.new(0.015, 0),
			PaddingBottom = UDim.new(0.015, 0),
		}),
	}

	if #props.GridItems == 0 then
		children.EmptyText = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = "No items in this category.",
			TextColor3 = ColorTokens.Text.Muted,
			TextSize = 18,
			TextWrapped = true,
		})
		return e(React.Fragment, {}, children)
	end

	for i, vm in ipairs(props.GridItems) do
		local key = if vm.IsEmpty then ("Empty_" .. tostring(vm.SlotIndex)) else ("Slot_" .. tostring(vm.SlotIndex))
		local isSelected = not vm.IsEmpty
			and props.SelectedSlotIndex ~= nil
			and vm.SlotIndex == props.SelectedSlotIndex
		children[key] = e(StaggeredInventorySlotCell, {
			Item = vm,
			IsSelected = isSelected,
			OnSelect = props.OnSelectItem,
			LayoutOrder = i,
			Index = i,
		})
	end

	return e(React.Fragment, {}, children)
end

return InventoryGrid
