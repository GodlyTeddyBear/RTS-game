--!strict
--[=[
	@class SidePanelView
	Wrapper organism that connects the SidePanel to the game controller, managing state and event handlers.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local MenuList = require(script.Parent.Parent.Molecules.MenuList)
local GradientTokens = require(script.Parent.Parent.Parent.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Config.TypographyTokens)

local PANEL_WIDTH_SCALE = 0.208
local TARGET_Y = 0.425
local HIDDEN_X = -0.15

export type TSidePanelViewProps = {
	panelRef: { current: Frame? },
	exitRef: { current: TextButton? },
	onExitMouseEnter: () -> (),
	onExitMouseLeave: () -> (),
	onExitActivated: () -> (),
	onNavigateFromMenu: (featureName: string) -> (),
}

local function SidePanelView(props: TSidePanelViewProps)
	return e("Frame", {
		ref = props.panelRef,
		Size = UDim2.fromScale(PANEL_WIDTH_SCALE, 0.488),
		Position = UDim2.fromScale(HIDDEN_X, TARGET_Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), -- white base needed for UIGradient tinting
		ClipsDescendants = true,
		ZIndex = 20,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.PANEL_GRADIENT,
			Rotation = -72,
		}),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.new(1, 1, 1),
			Thickness = 3,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE,
			}),
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),

		ScrollContainer = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.897, 0.74),
			ScrollBarThickness = 0,
		}, {
			MenuListComponent = e(MenuList, {
				OnNavigate = props.onNavigateFromMenu,
			}),
		}),

		ExitButton = e("TextButton", {
			ref = props.exitRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1), -- white base needed for UIGradient tinting
			ClipsDescendants = true,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 0.92),
			Size = UDim2.fromScale(0.897, 0.106),
			Text = "",
			TextSize = 1,
			[React.Event.MouseEnter] = props.onExitMouseEnter,
			[React.Event.MouseLeave] = props.onExitMouseLeave,
			[React.Event.Activated] = props.onExitActivated,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.TAB_INACTIVE_GRADIENT,
				Rotation = -2,
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 0),
			}),

			Label = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Typography.Font.Bold,
				Interactable = false,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.625, 0.472),
				Text = "Exit",
				TextColor3 = Colors.Text.Primary,
				TextSize = Typography.FontSize.H2,
				TextWrapped = true,
			}),
		}),
	})
end

return SidePanelView
