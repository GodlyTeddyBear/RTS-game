--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

--[=[
	@interface TCommissionFooterProps
	Props for CommissionFooter.
	.CanUnlock boolean -- Whether player has enough tokens to unlock next tier
	.HasNextTier boolean -- Whether next tier exists (false at max tier)
	.NextTierLabel string -- Label for next tier with cost info
	.OnUnlock () -> () -- Callback when unlock button clicked
	.LayoutOrder number? -- Optional layout order
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]

export type TCommissionFooterProps = {
	CanUnlock: boolean,
	HasNextTier: boolean,
	NextTierLabel: string,
	OnUnlock: () -> (),
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

-- Unlock button with hover spring; disabled when insufficient tokens or no next tier
type TUnlockButtonProps = {
	CanUnlock: boolean,
	OnUnlock: () -> (),
}

local function UnlockButton(props: TUnlockButtonProps)
	-- Green gradient when can unlock, disabled gradient when cannot
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.Tab)

	local gradient = if props.CanUnlock then GradientTokens.GREEN_BUTTON_GRADIENT else GradientTokens.SLOT_GRADIENT
	local stroke = if props.CanUnlock then GradientTokens.GREEN_BUTTON_STROKE else GradientTokens.SLOT_DECORE_STROKE

	return e("TextButton", {
		ref = buttonRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.76398, 0.90909),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = if props.CanUnlock
			then hover.onActivated(function()
				props.OnUnlock()
			end)
			else nil,
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
			Rotation = -140.856,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),

		Decore = e(Frame, {
			Size = UDim2.new(0.92683, 4, 0.75, 4),
			Position = UDim2.fromScale(0.50407, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			CornerRadius = UDim.new(0, 3),
			StrokeColor = stroke,
			StrokeThickness = 2,
			StrokeMode = Enum.ApplyStrokeMode.Border,
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
			Position = UDim2.fromScale(0.50407, 0.5),
			Size = UDim2.new(0.92683, 4, 0.75, 4),
			Text = "Unlock",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 16,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.new(1, 1, 1),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 2,
			}, {
				UIGradient = e("UIGradient", {
					Color = stroke,
				}),
			}),
		}),
	})
end

--[=[
	Footer bar displaying next tier unlock button and current tier info.
	@within CommissionFooter
	@param props TCommissionFooterProps
	@return Instance -- React frame element
]=]
local function CommissionFooter(props: TCommissionFooterProps)
	return e(Frame, {
		Size = UDim2.fromScale(1, 0.08105),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = props.LayoutOrder or 4,
		ClipsDescendants = true,
		ZIndex = 0,
		children = {
			-- Unlock button container (left-center)
			UnlockContainer = if props.HasNextTier
				then e("Frame", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.49965, 0.50602),
					Size = UDim2.fromScale(0.11181, 0.53012),
				}, {
					Button = e(UnlockButton, {
						CanUnlock = props.CanUnlock,
						OnUnlock = props.OnUnlock,
					}),
				})
				else nil,

			-- Next tier info (right side)
			TierFrame = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(if props.HasNextTier then 0.25174 else 0.5, 0.50602),
				Size = UDim2.fromScale(0.33681, 0.36145),
			}, {
				Label = if props.HasNextTier
					then e("TextLabel", {
						Active = true,
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothicA1.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromScale(0.42537, 1),
						Text = "Next tier:",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 25,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Right,
					})
					else nil,

				Amount = e("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.73321, 0.5),
					Size = UDim2.fromScale(0.53358, 1),
					Text = props.NextTierLabel,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),
		},
	})
end

return CommissionFooter
