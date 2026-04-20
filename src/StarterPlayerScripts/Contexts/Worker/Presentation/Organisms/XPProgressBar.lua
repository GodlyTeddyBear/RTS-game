--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local useAnimatedValue = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useAnimatedValue)

--[=[
	@interface TXPProgressBarProps
	@within XPProgressBar
	.Progress number -- Normalized progress 0–1
	.XPLabel string -- Text label to display (e.g., "150 / 500 XP")
	.Size UDim2? -- Size (optional; defaults to scale 1, 1)
	.Position UDim2? -- Position (optional; defaults to scale 0.5, 0.5)
	.AnchorPoint Vector2? -- AnchorPoint (optional; defaults to 0.5, 0.5)
	.LayoutOrder number? -- Layout order for parent list
]=]

export type TXPProgressBarProps = {
	Progress: number,
	XPLabel: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

--[=[
	Display animated XP progress bar with gradient fill and label.
	@within XPProgressBar
	@param props TXPProgressBarProps -- Component props
	@return React.Element -- Rendered progress bar frame
]=]
local function XPProgressBar(props: TXPProgressBarProps)
	local rawProgress = math.clamp(props.Progress or 0, 0, 1)
	-- Smooth animation over 0.4s when progress changes
	local progress = useAnimatedValue(rawProgress, {
		Duration = 0.4,
		EasingStyle = Enum.EasingStyle.Quad,
	})

	return e("Frame", {
		Active = true,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(17, 17, 17),
		ClipsDescendants = true,
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder,
	}, {
		UICorner = e("UICorner"),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.XP_BAR_STROKE,
			}),
		}),

		Fill = e("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(progress, 1),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.XP_BAR_GRADIENT,
			}),

			UICorner = e("UICorner"),
		}),

		XPLabel = e("TextLabel", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1.26),
			Text = props.XPLabel,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 14,
			TextWrapped = true,
			ZIndex = 2,
		}),
	})
end

return XPProgressBar
