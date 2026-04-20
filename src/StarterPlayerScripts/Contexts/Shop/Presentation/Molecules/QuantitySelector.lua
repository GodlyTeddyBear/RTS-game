--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

--[=[
	@interface TQuantitySelectorProps
	@within QuantitySelector
	.quantity number -- Current quantity value to display
	.animatedCost string -- Pre-animated cost string rendered below the controls
	.addBtnRef { current: TextButton? } -- Ref for the increment button (entrance/hover animation target)
	.minusBtnRef { current: TextButton? } -- Ref for the decrement button
	.addHover table -- Hover spring callbacks for the increment button
	.minusHover table -- Hover spring callbacks for the decrement button
	.onIncrement () -> () -- Increase quantity callback
	.onDecrement () -> () -- Decrease quantity callback
]=]
export type TQuantitySelectorProps = {
	quantity: number,
	animatedCost: string,
	addBtnRef: { current: TextButton? },
	minusBtnRef: { current: TextButton? },
	addHover: any,
	minusHover: any,
	onIncrement: () -> (),
	onDecrement: () -> (),
}

--[=[
	@class QuantitySelector
	Molecule for selecting item quantity. Renders increment/decrement buttons, a quantity display, and an animated cost label.
	@client
]=]

--[=[
	Render the quantity selector with +/- buttons, amount display, and cost label.
	@within QuantitySelector
	@param props TQuantitySelectorProps
	@return React.ReactElement -- Quantity selector container
]=]
local function QuantitySelector(props: TQuantitySelectorProps)
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 1,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(0.4303, 1),
	}, {
		-- Increment button (green)
		AddButton = e("TextButton", {
			ref = props.addBtnRef,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			LayoutOrder = 2,
			Position = UDim2.fromScale(0.00704, 0.50746),
			Size = UDim2.fromScale(0.28169, 0.59701),
			Text = "",
			TextSize = 1,
			[React.Event.MouseEnter] = props.addHover.onMouseEnter,
			[React.Event.MouseLeave] = props.addHover.onMouseLeave,
			[React.Event.Activated] = props.addHover.onActivated(props.onIncrement),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GREEN_ACTION_GRADIENT,
				Rotation = -3,
			}),

			UICorner = e("UICorner"),

			Decore = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.4875),
				Size = UDim2.fromScale(0.85, 0.825),
			}, {
				UIStroke = e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = GradientTokens.GREEN_ACTION_DECORE_COLOR,
					Thickness = 2,
				}),

				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),

			VectorImage = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = GradientTokens.ICON_PLUS,
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.5, 0.4875),
				Size = UDim2.fromScale(0.32813, 0.54375),
			}),
		}),

		-- Quantity display
		Amount = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 0.50746),
			Size = UDim2.fromScale(0.35211, 0.44776),
		}, {
			UIGradient = e("UIGradient", {
				Rotation = -141,
			}),

			UICorner = e("UICorner"),

			Label = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Body,
				Position = UDim2.fromScale(0.5, 0.51667),
				Size = UDim2.new(0.6, 2, 0.7, 2),
				Text = tostring(props.quantity),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextWrapped = true,
			}, {
				UIStroke = e("UIStroke", {
					Color = ColorTokens.Text.OnLight,
					LineJoinMode = Enum.LineJoinMode.Miter,
				}),
			}),
		}),

		-- Decrement button (red)
		MinusButton = e("TextButton", {
			ref = props.minusBtnRef,
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.99296, 0.50746),
			Size = UDim2.fromScale(0.28169, 0.59701),
			Text = "",
			TextSize = 1,
			[React.Event.MouseEnter] = props.minusHover.onMouseEnter,
			[React.Event.MouseLeave] = props.minusHover.onMouseLeave,
			[React.Event.Activated] = props.minusHover.onActivated(props.onDecrement),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.ASSIGN_BUTTON_GRADIENT,
				Rotation = -4,
			}),

			UICorner = e("UICorner"),

			Decore = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.4875),
				Size = UDim2.fromScale(0.85, 0.825),
			}, {
				UIStroke = e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = Color3.new(1, 1, 1),
					Thickness = 2,
				}, {
					UIGradient = e("UIGradient", {
						Color = GradientTokens.ASSIGN_BUTTON_STROKE,
					}),
				}),

				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),

			VectorImage = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = GradientTokens.ICON_MINUS,
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.5, 0.4875),
				Size = UDim2.fromScale(0.32813, 0.54375),
			}),
		}),

		-- Cost label (animated counter)
		Cost = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			LayoutOrder = 3,
			ZIndex = 2,
			Position = UDim2.new(0.5, 0, 0.02985, -2),
			Size = UDim2.new(1, 4, 0.14925, 4),
			Text = props.animatedCost,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 12,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = ColorTokens.Text.OnLight,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 2,
			}),
		}),
	})
end

return QuantitySelector
