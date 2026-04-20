--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useMemo = React.useMemo
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local ZoneViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ZoneViewModel)

--[=[
	@type TZoneTabBarProps
	@within ZoneTabBar
	.SelectedZone string -- Currently selected zone name
	.OnSelectZone (zoneName: string) -> () -- Zone selection callback
]=]
export type TZoneTabBarProps = {
	SelectedZone: string,
	OnSelectZone: (zoneName: string) -> (),
}

--[=[
	@class ZoneTabBar
	Renders zone tabs grouped by local and remote, with scrolling and selection.
	@client
]=]

local function ZoneTab(props: {
	Name: string,
	LayoutOrder: number,
	IsSelected: boolean,
	OnActivated: () -> (),
})
	local gradient = if props.IsSelected
		then GradientTokens.TAB_ACTIVE_GRADIENT
		else GradientTokens.TAB_INACTIVE_GRADIENT

	local btnRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(btnRef, AnimationTokens.Interaction.Tab)

	return e("TextButton", {
		ref = btnRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 32),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(props.OnActivated),
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),

		UIStroke = if props.IsSelected
			then e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 2,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.TAB_ACTIVE_STROKE,
				}),
			})
			else nil,

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.75),
			Text = props.Name,
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.Body,
			TextWrapped = true,
		}),
	})
end

local function GroupLabel(props: { Text: string, LayoutOrder: number })
	return e("TextLabel", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 20),
		Text = props.Text,
		TextColor3 = Colors.Text.Muted,
		TextSize = Typography.FontSize.Caption,
		Font = Typography.Font.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function ZoneTabBar(props: TZoneTabBarProps)
	local groups = useMemo(function()
		return ZoneViewModel.buildZoneGroups()
	end, {})

	local children: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	}

	local order = 0

	-- Local group
	order += 1
	children["LocalLabel"] = e(GroupLabel, { Text = "LOCAL", LayoutOrder = order })

	for _, zoneInfo in groups.localGroup.Zones do
		order += 1
		children["Zone_" .. zoneInfo.Name] = e(ZoneTab, {
			Name = zoneInfo.Name,
			LayoutOrder = order,
			IsSelected = props.SelectedZone == zoneInfo.Name,
			OnActivated = function()
				props.OnSelectZone(zoneInfo.Name)
			end,
		})
	end

	-- Separator
	order += 1
	children["Separator"] = e("Frame", {
		BackgroundColor3 = Colors.Border.Subtle,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 1),
	})

	-- Remote group
	order += 1
	children["RemoteLabel"] = e(GroupLabel, { Text = "REMOTE", LayoutOrder = order })

	for _, zoneInfo in groups.remoteGroup.Zones do
		order += 1
		children["Zone_" .. zoneInfo.Name] = e(ZoneTab, {
			Name = zoneInfo.Name,
			LayoutOrder = order,
			IsSelected = props.SelectedZone == zoneInfo.Name,
			OnActivated = function()
				props.OnSelectZone(zoneInfo.Name)
			end,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.PANEL_GRADIENT,
			Rotation = 90,
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

		Scroll = e("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Colors.Accent.Yellow,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
		}, children),
	})
end

return ZoneTabBar
