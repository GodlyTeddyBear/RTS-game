--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local useAnimatedVisibility = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useAnimatedVisibility)
local ZoneTabBar = require(script.Parent.Parent.Organisms.ZoneTabBar)
local ZoneSlotGrid = require(script.Parent.Parent.Organisms.ZoneSlotGrid)

--[=[
	@type TBuildingScreenViewProps
	@within BuildingScreenView
	.containerRef { current: Frame? } -- Root frame reference
	.onBack () -> () -- Back button callback
	.selectedZone string -- Currently selected zone
	.onSelectZone (zoneName: string) -> () -- Zone selection callback
	.playerBuildings { [string]: any } -- Buildings data by zone
	.selectedSlot number? -- Currently selected slot
	.onSelectSlot (slotIndex: number) -> () -- Slot selection callback
	.rightPanel any? -- Detail or picker panel (or nil)
]=]
type TBuildingScreenViewProps = {
	containerRef: { current: Frame? },
	onBack: () -> (),
	selectedZone: string,
	onSelectZone: (zoneName: string) -> (),
	playerBuildings: { [string]: any },
	selectedSlot: number?,
	onSelectSlot: (slotIndex: number) -> (),
	rightPanel: any?,
}

--[=[
	@class BuildingScreenView
	Renders the building screen layout with header, zone tabs, slot grid, and right panel.
	@client
]=]
local function BuildingScreenView(props: TBuildingScreenViewProps)
	local panelVisibility = useAnimatedVisibility(props.rightPanel ~= nil, {
		Mode = "slideRight",
		SpringPreset = "Smooth",
	})

	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0.094),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.BAR_GRADIENT,
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.GOLD_STROKE,
				}),
			}),
			BackButton = e("TextButton", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Font = Typography.Font.Bold,
				Position = UDim2.fromScale(0.02, 0.5),
				Size = UDim2.fromScale(0.1, 0.7),
				Text = "< Back",
				TextColor3 = Colors.Accent.Yellow,
				TextSize = Typography.FontSize.Body,
				[React.Event.Activated] = props.onBack,
			}),
			Title = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Typography.Font.Bold,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.7),
				Text = "Buildings & Lots",
				TextColor3 = Colors.Text.Primary,
				TextSize = Typography.FontSize.H3,
			}),
		}),
		Content = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.094),
			Size = UDim2.fromScale(1, 0.906),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.LIST_CONTAINER_GRADIENT,
				Rotation = -16,
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.GOLD_STROKE,
				}),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.005, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ZoneTabs = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.185, 0.97),
			}, {
				ZoneTabBar = e(ZoneTabBar, {
					SelectedZone = props.selectedZone,
					OnSelectZone = props.onSelectZone,
				}),
			}),
			SlotGrid = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = if panelVisibility.shouldRender then UDim2.fromScale(0.435, 0.97) else UDim2.fromScale(0.79, 0.97),
			}, {
				ZoneSlotGrid = e(ZoneSlotGrid, {
					ZoneName = props.selectedZone,
					PlayerBuildings = props.playerBuildings,
					SelectedSlot = props.selectedSlot,
					OnSelectSlot = props.onSelectSlot,
				}),
			}),
			RightPanel = if panelVisibility.shouldRender
				then e("Frame", {
					ref = panelVisibility.containerRef,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					Size = UDim2.fromScale(0.35, 0.97),
				}, {
					Panel = props.rightPanel,
				})
				else nil,
		}),
	})
end

return BuildingScreenView
