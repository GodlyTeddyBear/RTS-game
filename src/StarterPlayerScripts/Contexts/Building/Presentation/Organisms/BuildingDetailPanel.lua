--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local SlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.SlotViewModel)

--[=[
	@type TBuildingDetailPanelProps
	@within BuildingDetailPanel
	.ZoneName string -- Zone containing the building
	.SlotData SlotViewModel.TSlotData -- Slot data with building and level info
	.OnUpgrade () -> () -- Upgrade button callback
	.OnClose () -> () -- Close button callback
]=]
export type TBuildingDetailPanelProps = {
	ZoneName: string,
	SlotData: SlotViewModel.TSlotData,
	OnUpgrade: () -> (),
	OnClose: () -> (),
}

--[=[
	@class BuildingDetailPanel
	Displays building details: name, level, progress bar, upgrade cost, and action buttons.
	@client
]=]

local function BuildingDetailPanel(props: TBuildingDetailPanelProps)
	local slot = props.SlotData

	local closeBtnRef = useRef(nil :: TextButton?)
	local upgradeBtnRef = useRef(nil :: TextButton?)
	local closeHover = useHoverSpring(closeBtnRef, AnimationTokens.Interaction.ActionButton)
	local upgradeHover = useHoverSpring(upgradeBtnRef, {
		HoverScale = AnimationTokens.Interaction.ActionButton.HoverScale,
		PressScale = AnimationTokens.Interaction.ActionButton.PressScale,
		SpringPreset = AnimationTokens.Interaction.ActionButton.SpringPreset,
		Disabled = slot.IsMaxLevel,
	})

	return e("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.LIST_CONTAINER_GRADIENT,
			Rotation = -16,
		}),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),

		-- Building name
		Title = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.5, 0.04),
			Size = UDim2.fromScale(0.85, 0.1),
			Text = slot.BuildingType or "",
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.H3,
			TextWrapped = true,
		}),

		-- Zone / slot label
		Subtitle = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Typography.Font.Body,
			Position = UDim2.fromScale(0.5, 0.16),
			Size = UDim2.fromScale(0.85, 0.07),
			Text = props.ZoneName .. " — Slot " .. tostring(slot.SlotIndex),
			TextColor3 = Colors.Text.Muted,
			TextSize = Typography.FontSize.Small,
			TextWrapped = true,
		}),

		-- Level display
		LevelLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.5, 0.28),
			Size = UDim2.fromScale(0.85, 0.09),
			Text = slot.LevelText,
			TextColor3 = if slot.IsMaxLevel then Colors.Accent.Yellow else Colors.Text.Secondary,
			TextSize = Typography.FontSize.Body,
		}),

		-- Level bar
		LevelBarBg = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Colors.Surface.Secondary,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.85, 0.035),
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(
					math.clamp((slot.Level or 0) / (slot.MaxLevel or 1), 0, 1),
					1
				),
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.XP_BAR_GRADIENT,
				}),
				UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),

		-- Upgrade cost / max level badge
		UpgradeInfo = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Typography.Font.Body,
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.85, 0.08),
			Text = slot.UpgradeCostText,
			TextColor3 = if slot.IsMaxLevel then Colors.Accent.Yellow else Colors.Text.Secondary,
			TextSize = Typography.FontSize.Small,
			TextWrapped = true,
		}),

		-- Actions
		Actions = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(0.9, 0.12),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			CloseButton = e("TextButton", {
				ref = closeBtnRef,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.35, 0.85),
				Text = "",
				TextSize = 1,
				[React.Event.MouseEnter] = closeHover.onMouseEnter,
				[React.Event.MouseLeave] = closeHover.onMouseLeave,
				[React.Event.Activated] = closeHover.onActivated(props.OnClose),
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.TAB_INACTIVE_GRADIENT,
				}),
				UICorner = e("UICorner"),
				Label = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Typography.Font.Bold,
					Interactable = false,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.7),
					Text = "Close",
					TextColor3 = Colors.Text.Primary,
					TextSize = Typography.FontSize.Small,
				}),
			}),

			UpgradeButton = e("TextButton", {
				ref = upgradeBtnRef,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.5, 0.85),
				Text = "",
				TextSize = 1,
				[React.Event.MouseEnter] = upgradeHover.onMouseEnter,
				[React.Event.MouseLeave] = upgradeHover.onMouseLeave,
				[React.Event.Activated] = if not slot.IsMaxLevel
					then upgradeHover.onActivated(props.OnUpgrade)
					else function() end,
			}, {
				UIGradient = e("UIGradient", {
					Color = if not slot.IsMaxLevel
						then GradientTokens.GREEN_ACTION_GRADIENT
						else GradientTokens.TAB_INACTIVE_GRADIENT,
					Rotation = -3,
				}),
				UICorner = e("UICorner"),
				Label = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Typography.Font.Bold,
					Interactable = false,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.7),
					Text = if not slot.IsMaxLevel then "Upgrade" else "Max Level",
					TextColor3 = if not slot.IsMaxLevel then Colors.Text.Primary else Colors.Text.Muted,
					TextSize = Typography.FontSize.Small,
				}),
			}),
		}),
	})
end

return BuildingDetailPanel
