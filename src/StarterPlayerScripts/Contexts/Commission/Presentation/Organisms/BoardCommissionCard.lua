--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local BoardCommissionViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.BoardCommissionViewModel)

--[=[
	@interface TBoardCommissionCardProps
	Props for BoardCommissionCard.
	.Commission BoardCommissionViewModel.TBoardCommissionVM -- View model for display
	.OnAccept (commissionId: string) -> () -- Callback when accept button clicked
	.LayoutOrder number? -- Optional layout order in list
]=]

export type TBoardCommissionCardProps = {
	Commission: BoardCommissionViewModel.TBoardCommissionVM,
	OnAccept: (commissionId: string) -> (),
	LayoutOrder: number?,
}

-- Accept button with hover spring; disabled when player has full active slots (CanAccept = false)
type TAcceptButtonProps = {
	CanAccept: boolean,
	OnAccept: () -> (),
}

local function AcceptButton(props: TAcceptButtonProps)
	-- Shows "Accept" when slots available, "Full" when at capacity
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.ActionButton)

	return e("TextButton", {
		ref = buttonRef,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		LayoutOrder = 3,
		Position = UDim2.fromScale(0.83937, 0.50714),
		Size = UDim2.fromScale(0.13788, 0.72857),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = if props.CanAccept
			then hover.onActivated(function()
				props.OnAccept()
			end)
			else nil,
	}, {
		UIGradient = e("UIGradient", {
			Color = if props.CanAccept
				then GradientTokens.ASSIGN_BUTTON_GRADIENT
				else GradientTokens.SLOT_GRADIENT,
			Rotation = -4,
		}),

		UICorner = e("UICorner"),

		Decore = e("Frame", {
			Active = true,
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
					Color = if props.CanAccept
						then GradientTokens.ASSIGN_BUTTON_STROKE
						else GradientTokens.SLOT_DECORE_STROKE,
				}),
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),

		Label = e("TextLabel", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothicA1.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Interactable = false,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 0.4902),
			Size = UDim2.new(0.94845, 4, 0.58824, 4),
			Text = if props.CanAccept then "Accept" else "Full",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 25,
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
	Display a single board commission with item requirement and accept button.
	@within BoardCommissionCard
	@param props TBoardCommissionCardProps
	@return Instance -- React frame element
]=]
local function BoardCommissionCard(props: TBoardCommissionCardProps)
	local c = props.Commission

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
				Text = c.QuantityLabel,
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

			-- Empty fill for board commissions (0 progress)
			Fill = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(0, 1),
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

		-- Accept button (right)
		AcceptButton = e(AcceptButton, {
			CanAccept = c.CanAccept,
			OnAccept = function()
				props.OnAccept(c.Id)
			end,
		}),
	})
end

return BoardCommissionCard
