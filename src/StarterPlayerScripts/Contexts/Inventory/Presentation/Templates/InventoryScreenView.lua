--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

local InventoryHeader = require(script.Parent.Parent.Organisms.InventoryHeader)
local InventoryTabBar = require(script.Parent.Parent.Organisms.InventoryTabBar)
local InventoryGrid = require(script.Parent.Parent.Organisms.InventoryGrid)
local ItemDetailPanel = require(script.Parent.Parent.Organisms.ItemDetailPanel)
local InventoryFooter = require(script.Parent.Parent.Organisms.InventoryFooter)
local InventorySlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.InventorySlotViewModel)

--[=[
	@interface TInventoryScreenViewProps
	@within InventoryScreenView
	.ContainerRef { current: Frame? } -- Root container reference
	.UsedSlots number -- Occupied slot count
	.TotalSlots number -- Total slot capacity
	.TabInfo { InventoryTabBar.TTabInfo } -- Category tabs
	.ActiveTab string -- Currently selected tab
	.GridItems { InventorySlotViewModel } -- Items to display
	.SelectedItem InventorySlotViewModel? -- Selected item or nil
	.SelectedSlotIndex number? -- Selected slot index or nil
	.OnBack () -> () -- Back navigation
	.OnTabSelect (tabName: string) -> () -- Tab selection
	.OnSelectItem (item: InventorySlotViewModel) -> () -- Item selection
]=]
type TInventoryScreenViewProps = {
	ContainerRef: { current: Frame? },
	UsedSlots: number,
	TotalSlots: number,
	TabInfo: { InventoryTabBar.TTabInfo },
	ActiveTab: string,
	GridItems: { InventorySlotViewModel.TInventorySlotViewModel },
	SelectedItem: InventorySlotViewModel.TInventorySlotViewModel?,
	SelectedSlotIndex: number?,
	OnBack: () -> (),
	OnTabSelect: (tabName: string) -> (),
	OnSelectItem: (item: InventorySlotViewModel.TInventorySlotViewModel) -> (),
}

--[=[
	@function InventoryScreenView
	@within InventoryScreenView
	Render the complete inventory UI with header, tabs, grid, and detail panel.
	@param props TInventoryScreenViewProps
	@return React.ReactElement
]=]
local function InventoryScreenView(props: TInventoryScreenViewProps)
	return e("Frame", {
		ref = props.ContainerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e(InventoryHeader, {
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.OnBack,
		}),

		TabBar = e(InventoryTabBar, {
			Position = UDim2.fromScale(0.5, 0.12779),
			UsedSlots = props.UsedSlots,
			TotalSlots = props.TotalSlots,
			Tabs = props.TabInfo,
			ActiveTab = props.ActiveTab,
			OnTabSelect = props.OnTabSelect,
		}),

		Content = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.53826),
			Size = UDim2.fromScale(1, 0.76172),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.LIST_CONTAINER_GRADIENT,
			GradientRotation = -16,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			ClipsDescendants = true,
			children = {
				Container = e("Frame", {
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
						ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
						ClipsDescendants = true,
					}, {
						Grid = e(InventoryGrid, {
							GridItems = props.GridItems,
							SelectedSlotIndex = props.SelectedSlotIndex,
							ActiveTab = props.ActiveTab,
							OnSelectItem = props.OnSelectItem,
						}),
					}),
				}),

				DetailPanel = e(ItemDetailPanel, {
					Item = props.SelectedItem,
				}),
			},
		}),

		Footer = e(InventoryFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
		}),
	})
end

return InventoryScreenView
