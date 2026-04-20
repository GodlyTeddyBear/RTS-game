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

export type TOptionTab = {
	label: string,
	key: string,
	secondaryText: string?,
	quantityText: string?,
	disabled: boolean?,
}

export type TOptionAreaPanelProps = {
	options: { TOptionTab },
	selectedKey: string?,
	activeShotKey: string?,
	onOptionSelected: (key: string) -> (),
}

type TOptionTabButtonProps = {
	option: TOptionTab,
	isSelected: boolean,
	layoutOrder: number,
	onOptionSelected: (key: string) -> (),
}

local function OptionTabButton(props: TOptionTabButtonProps)
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef :: any, TAB_INTERACTION)
	local isDisabled = props.option.disabled == true
	local isSelected = props.isSelected and not isDisabled
	local hasDetails = props.option.secondaryText ~= nil or props.option.quantityText ~= nil

	-- Outer Frame is positioned by UIListLayout; inner button is centered
	-- so UIScale scales symmetrically from the button's center.
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, if hasDetails then 42 else 32),
	}, {
		Button = e("TextButton", {
			ref = buttonRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = if isSelected
				then COLOR_TAB_SELECTED
				elseif isDisabled then Color3.fromRGB(26, 24, 24)
				else COLOR_TAB_NORMAL,
			BorderSizePixel = 0,
			FontFace = GOTHIC_BOLD,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextColor3 = if isDisabled then Color3.fromRGB(145, 145, 145) else Color3.new(1, 1, 1),
			TextSize = 11,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Event.MouseEnter] = if isDisabled then nil else hover.onMouseEnter,
			[React.Event.MouseLeave] = if isDisabled then nil else hover.onMouseLeave,
			[React.Event.Activated] = if isDisabled
				then nil
				else hover.onActivated(function()
					props.onOptionSelected(props.option.key)
				end),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(135, 135, 135),
				Thickness = 1,
				Transparency = if isSelected then 0.3 elseif isDisabled then 0.8 else 0.7156,
			}),
			Label = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				FontFace = GOTHIC_BOLD,
				Position = if hasDetails then UDim2.fromScale(0, 0.08) else UDim2.fromScale(0, 0),
				Size = if hasDetails then UDim2.fromScale(0.72, 0.43) else UDim2.fromScale(1, 1),
				Text = props.option.label,
				TextColor3 = if isDisabled then Color3.fromRGB(145, 145, 145) else Color3.new(1, 1, 1),
				TextSize = 11,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Quantity = if props.option.quantityText
				then e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					FontFace = GOTHIC_BOLD,
					Position = UDim2.fromScale(1, 0.08),
					Size = UDim2.fromScale(0.24, 0.43),
					Text = props.option.quantityText,
					TextColor3 = if isDisabled then Color3.fromRGB(145, 145, 145) else Color3.new(1, 1, 1),
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
				else nil,
			Secondary = if props.option.secondaryText
				then e("TextLabel", {
					AnchorPoint = Vector2.new(0, 1),
					BackgroundTransparency = 1,
					FontFace = GOTHIC_BOLD,
					Position = UDim2.fromScale(0, 0.92),
					Size = UDim2.fromScale(1, 0.38),
					Text = props.option.secondaryText,
					TextColor3 = if isDisabled then Color3.fromRGB(145, 145, 145) else COLOR_TAB_SELECTED,
					TextSize = 10,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				else nil,
		}),
	})
end

local function OptionAreaPanel(props: TOptionAreaPanelProps)
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

	for i, option in ipairs(props.options) do
		tabChildren["Tab_" .. option.key] = e(OptionTabButton, {
			option = option,
			isSelected = props.selectedKey == option.key or props.activeShotKey == option.key,
			layoutOrder = i,
			onOptionSelected = props.onOptionSelected,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5184, 0.89746),
		Size = UDim2.fromScale(0.43681, 0.20508),
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
			Size = UDim2.fromScale(0.95866, 0.90476),
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

return OptionAreaPanel
