--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

local StaggeredShopSlotCell = require(script.Parent.StaggeredShopSlotCell)
local ShopSlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ShopSlotViewModel)

-- Grid layout constants.
local COLUMNS = 5
local H_PADDING = 0.02
local H_GAP = 0.02
local V_GAP = 0.02
local CELL_WIDTH = (1 - (H_PADDING * 2) - (H_GAP * (COLUMNS - 1))) / COLUMNS
local CELL_HEIGHT = CELL_WIDTH * 1.23274

--[=[
	@interface TShopGridProps
	@within ShopGrid
	.GridItems { ShopSlotViewModel.TShopSlotViewModel } -- Filtered items to display in the grid
	.SelectedItem ShopSlotViewModel.TShopSlotViewModel? -- Currently selected item (drives selection highlight)
	.ActiveTab "buy" | "sell" -- Used for empty state message
	.OnSelectItem (item: ShopSlotViewModel.TShopSlotViewModel) -> () -- Selection callback
]=]
export type TShopGridProps = {
	GridItems: { ShopSlotViewModel.TShopSlotViewModel },
	SelectedItem: ShopSlotViewModel.TShopSlotViewModel?,
	ActiveTab: "buy" | "sell",
	OnSelectItem: (item: ShopSlotViewModel.TShopSlotViewModel) -> (),
}

--[=[
	@class ShopGrid
	Scrollable item grid for the Shop screen. Renders staggered slot cells or an empty state message.
	@client
]=]

--[=[
	Render the shop item grid with UIGridLayout and optional empty state.
	@within ShopGrid
	@param props TShopGridProps
	@return React.ReactElement -- Scrollable grid container
]=]
local function ShopGrid(props: TShopGridProps)
	local gridChildren: { [string]: any } = {
		UIGridLayout = e("UIGridLayout", {
			CellSize = UDim2.fromScale(CELL_WIDTH, CELL_HEIGHT),
			CellPadding = UDim2.fromScale(H_GAP, V_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			FillDirectionMaxCells = COLUMNS,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(H_PADDING, 0),
			PaddingRight = UDim.new(H_PADDING, 0),
			PaddingTop = UDim.new(0.015, 0),
			PaddingBottom = UDim.new(0.015, 0),
		}),
	}

	if #props.GridItems == 0 then
		gridChildren["EmptyText"] = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = if props.ActiveTab == "buy"
				then "No items available for purchase."
				else "No sellable items in inventory.",
			TextColor3 = ColorTokens.Text.Muted,
			TextSize = 18,
			TextWrapped = true,
		})
	else
		for i, vm in ipairs(props.GridItems) do
			local key = "Slot_" .. tostring(vm.ItemId) .. "_" .. tostring(vm.SlotIndex)
			local isSelected = props.SelectedItem ~= nil
				and vm.ItemId == props.SelectedItem.ItemId
				and vm.SlotIndex == props.SelectedItem.SlotIndex
			gridChildren[key] = e(StaggeredShopSlotCell, {
				Item = vm,
				IsSelected = isSelected,
				OnSelect = props.OnSelectItem,
				LayoutOrder = i,
				Index = i,
			})
		end
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.33472, 0.5),
		Size = UDim2.fromScale(0.64583, 0.96154),
	}, {
		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 3,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),
		ContainerScroll = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0.5, 0.49933),
			Size = UDim2.new(1, -12, 1, -10),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = GradientTokens.GOLD_SCROLLBAR_COLOR,
			ClipsDescendants = true,
		}, gridChildren),
	})
end

return ShopGrid
