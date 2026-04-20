--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useAnimatedValue = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useAnimatedValue)

local ActiveCommissionViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.ActiveCommissionViewModel)

--[=[
	@interface TActiveCommissionCardProps
	Props for ActiveCommissionCard.
	.Commission ActiveCommissionViewModel.TActiveCommissionVM -- View model for display
	.OnDeliver (commissionId: string) -> () -- Callback when deliver button clicked
	.OnAbandon (commissionId: string) -> () -- Callback when abandon button clicked
	.LayoutOrder number? -- Optional layout order in list
]=]

export type TActiveCommissionCardProps = {
	Commission: ActiveCommissionViewModel.TActiveCommissionVM,
	OnDeliver: (commissionId: string) -> (),
	OnAbandon: (commissionId: string) -> (),
	LayoutOrder: number?,
}

-- Deliver button with hover spring animation; conditionally enabled when commission is complete
type TDeliverButtonProps = {
	IsComplete: boolean,
	OnDeliver: () -> (),
}

local function DeliverButton(props: TDeliverButtonProps)
	-- Green gradient when complete, disabled when incomplete
	-- Hover spring scales the button on interaction
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.ActionButton)

	local gradient = if props.IsComplete
		then GradientTokens.GREEN_BUTTON_GRADIENT
		else GradientTokens.SLOT_GRADIENT
	local stroke = if props.IsComplete
		then GradientTokens.GREEN_BUTTON_STROKE
		else GradientTokens.SLOT_DECORE_STROKE
	local labelStrokeColor = if props.IsComplete
		then Color3.fromRGB(12, 44, 20)
		else Color3.fromRGB(30, 30, 30)

	return e("TextButton", {
		ref = buttonRef,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.83937, 0.30),
		Size = UDim2.fromScale(0.13788, 0.40),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = if props.IsComplete
			then hover.onActivated(function()
				props.OnDeliver()
			end)
			else nil,
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
			Rotation = -4,
		}),

		UICorner = e("UICorner"),

		Decore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.4902),
			Size = UDim2.fromScale(0.94845, 0.82353),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.new(1, 1, 1),
				Thickness = 2,
			}, {
				UIGradient = e("UIGradient", {
					Color = stroke,
				}),
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothicA1.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.4902),
			Size = UDim2.new(0.94845, 4, 0.58824, 4),
			Text = if props.IsComplete then "Deliver" else "Incomplete",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 20,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = labelStrokeColor,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 2,
			}),
		}),
	})
end

-- Abandon button with hover spring animation; always enabled
type TAbandonButtonProps = {
	OnAbandon: () -> (),
}

local function AbandonButton(props: TAbandonButtonProps)
	-- Red gradient button with hover effect; always clickable regardless of progress
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.ActionButton)

	return e("TextButton", {
		ref = buttonRef,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.83937, 0.74),
		Size = UDim2.fromScale(0.13788, 0.35),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(function()
			props.OnAbandon()
		end),
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
			Position = UDim2.fromScale(0.5, 0.4902),
			Size = UDim2.fromScale(0.94845, 0.82353),
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

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothicA1.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.4902),
			Size = UDim2.new(0.94845, 4, 0.58824, 4),
			Text = "Abandon",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 18,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(96, 2, 4),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 2,
			}),
		}),
	})
end

--[=[
	Display a single active commission with progress bar and action buttons.
	@within ActiveCommissionCard
	@param props TActiveCommissionCardProps
	@return Instance -- React frame element
]=]
local function ActiveCommissionCard(props: TActiveCommissionCardProps)
	local c = props.Commission

	-- Calculate progress ratio and animate fill transition (0.4s quad easing)
	local rawProgress = math.clamp(if c.RequiredQty > 0 then c.CurrentQty / c.RequiredQty else 0, 0, 1)
	local progressRatio = useAnimatedValue(rawProgress, { Duration = 0.4, EasingStyle = Enum.EasingStyle.Quad })

	return e("Frame", {
		Active = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 2, 0.09346, 2),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.TAB_INACTIVE_GRADIENT,
			Rotation = -2,
		}),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			LineJoinMode = Enum.LineJoinMode.Miter,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),

		-- TypeInfo (left)
		TypeInfo = e("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.04691, 0.50714),
			Size = UDim2.fromScale(0.1258, 0.72857),
		}, {
			Name = e("TextLabel", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.new(0.47458, 0, 0, -2),
				Size = UDim2.new(0.94915, 4, 0.4902, 4),
				Text = c.ItemName,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				UIStroke = e("UIStroke", {
					Color = Color3.fromRGB(4, 4, 4),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 2,
				}),
			}),

			Level = e("TextLabel", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.31356, 1),
				Size = UDim2.fromScale(0.62712, 0.43137),
				Text = c.TierLabel,
				TextColor3 = Color3.fromRGB(135, 135, 135),
				TextSize = 21,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		-- Progress bar (middle)
		Bar = e("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(17, 17, 17),
			ClipsDescendants = true,
			LayoutOrder = 2,
			Position = UDim2.fromScale(0.35714, 0.50714),
			Size = UDim2.new(0.24662, 4, 0.32857, 4),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 2,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.XP_BAR_STROKE,
				}),
			}),

			UICorner = e("UICorner"),

			Fill = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(progressRatio, 1),
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.XP_BAR_GRADIENT,
				}),

				UICorner = e("UICorner"),
			}),

			ProgressLabel = e("TextLabel", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1.26087),
				Text = c.ProgressLabel,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextWrapped = true,
			}),
		}),

		-- RewardInfo (middle-right)
		RewardInfo = e("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5995, 0.50714),
			Size = UDim2.fromScale(0.1258, 0.72857),
		}, {
			Gold = e("TextLabel", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Position = UDim2.fromScale(0.31356, 0),
				Size = UDim2.fromScale(0.62712, 0.43137),
				Text = c.GoldReward,
				TextColor3 = Color3.fromRGB(135, 135, 135),
				TextSize = 21,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Token = e("TextLabel", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.31356, 1),
				Size = UDim2.fromScale(0.62712, 0.43137),
				Text = c.TokenReward,
				TextColor3 = Color3.fromRGB(135, 135, 135),
				TextSize = 21,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		-- Deliver button (right, upper)
		DeliverBtn = e(DeliverButton, {
			IsComplete = c.IsComplete,
			OnDeliver = function()
				props.OnDeliver(c.Id)
			end,
		}),

		-- Abandon button (right, lower)
		AbandonBtn = e(AbandonButton, {
			OnAbandon = function()
				props.OnAbandon(c.Id)
			end,
		}),
	})
end

return ActiveCommissionCard
