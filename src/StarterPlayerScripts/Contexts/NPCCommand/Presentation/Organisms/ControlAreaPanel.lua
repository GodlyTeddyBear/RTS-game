--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)

local GOTHIC_BOLD = Font.new(
	"rbxasset://fonts/families/GothicA1.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

local PANEL_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
	ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
})

local COLOR_TAB_NORMAL = Color3.fromRGB(40, 34, 34)
local COLOR_TAB_SELECTED = Color3.fromRGB(233, 195, 73)

local TAB_INTERACTION = AnimationTokens.Interaction.Tab

export type TControlTab = {
	label: string,
	key: string,
}

export type TControlAreaPanelProps = {
	tabs: { TControlTab },
	selectedKey: string?,
	onTabSelected: (key: string) -> (),
}

type TControlTabButtonProps = {
	tab: TControlTab,
	isSelected: boolean,
	layoutOrder: number,
	onTabSelected: (key: string) -> (),
}

local function ControlTabButton(props: TControlTabButtonProps)
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef :: any, TAB_INTERACTION)
	local isSelected = props.isSelected

	-- Outer Frame is positioned by UIListLayout; inner button is centered
	-- so UIScale scales symmetrically from the button's center.
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, 32),
	}, {
		Button = e("TextButton", {
			ref = buttonRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = if isSelected then COLOR_TAB_SELECTED else COLOR_TAB_NORMAL,
			BorderSizePixel = 0,
			FontFace = GOTHIC_BOLD,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Text = props.tab.label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 11,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Event.MouseEnter] = hover.onMouseEnter,
			[React.Event.MouseLeave] = hover.onMouseLeave,
			[React.Event.Activated] = hover.onActivated(function()
				props.onTabSelected(props.tab.key)
			end),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(135, 135, 135),
				Thickness = 1,
				Transparency = if isSelected then 0.3 else 0.7156,
			}),
		}),
	})
end

local function ControlAreaPanel(props: TControlAreaPanelProps)
	local tabChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
		}),
	}

	for i, tab in ipairs(props.tabs) do
		tabChildren["Tab_" .. tab.key] = e(ControlTabButton, {
			tab = tab,
			isSelected = props.selectedKey == tab.key,
			layoutOrder = i,
			onTabSelected = props.onTabSelected,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.20729, 0.89746),
		Size = UDim2.fromScale(0.15208, 0.20508),
	}, {
		UIGradient = e("UIGradient", {
			Color = PANEL_GRADIENT,
			Rotation = -140.856,
		}),
		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.fromRGB(135, 135, 135),
			Thickness = 4,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Content = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.90868, 0.89524),
		}, {
			TabScroll = e("ScrollingFrame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.5, 0.5),
				ScrollBarThickness = 2,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(1, 1),
			}, tabChildren),
		}),
	})
end

return ControlAreaPanel
