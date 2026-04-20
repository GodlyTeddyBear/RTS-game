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
	@interface TPartySelectionStatusBarProps
	Props for the party selection status bar component.
	@within PartySelectionStatusBar
	.SelectedCount number -- Number of currently selected adventurers
	.PartySizeLabel string -- Formatted party size requirement (e.g. "1-3 Adventurers")
	.OnConfirm () -> () -- Called when confirm button is clicked
	.ConfirmEnabled boolean -- Whether confirm button should be enabled
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
	.LayoutOrder number? -- Optional layout order
	.ZIndex number? -- Optional z-index
]=]
export type TPartySelectionStatusBarProps = {
	SelectedCount: number,
	PartySizeLabel: string,
	OnConfirm: () -> (),
	ConfirmEnabled: boolean,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}

--[=[
	@class PartySelectionStatusBar
	Status bar for party selection showing party size info and confirm button.
	Displays the party size requirement and current selection count.
	@client
]=]
local function PartySelectionStatusBar(props: TPartySelectionStatusBarProps)
	local confirmBtnRef = useRef(nil :: TextButton?)
	local confirmHover = useHoverSpring(confirmBtnRef, AnimationTokens.Interaction.ActionButton)

	local btnGradient = if props.ConfirmEnabled
		then GradientTokens.GREEN_BUTTON_GRADIENT
		else GradientTokens.SLOT_GRADIENT

	local btnDecoreStroke = if props.ConfirmEnabled
		then GradientTokens.GREEN_BUTTON_STROKE
		else GradientTokens.SLOT_DECORE_STROKE

	local btnLabelStroke = if props.ConfirmEnabled
		then GradientTokens.GREEN_BUTTON_STROKE
		else GradientTokens.SLOT_DECORE_STROKE

	return e(Frame, {
		Size = UDim2.fromScale(1, 0.05957),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
		ClipsDescendants = true,
		children = {
			-- "Party Size: 1-3 Adventurers"
			SizeFrame = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.02708, 0.45902),
				Size = UDim2.fromScale(0.27083, 0.4918),
			}, {
				Label = e("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothicA1.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(0.38718, 1),
					Text = "Party Size:",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),

				Amount = e("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.70769, 0.5),
					Size = UDim2.fromScale(0.58462, 1),
					Text = props.PartySizeLabel,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- "Selected: N"
			SelectedFrame = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.39583, 0.47541),
				Size = UDim2.fromScale(0.20833, 0.52459),
			}, {
				Label = e("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothicA1.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.285, 0.46875),
					Size = UDim2.fromScale(0.57, 0.9375),
					Text = "Selected:",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),

				Amount = e("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(1, 0.53125),
					Size = UDim2.fromScale(0.39333, 0.9375),
					Text = tostring(props.SelectedCount),
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- Confirm button
			ConfirmContainer = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				LayoutOrder = 2,
				Position = UDim2.fromScale(0.70486, 0.4918),
				Size = UDim2.fromScale(0.32778, 0.72131),
			}, {
				ConfirmButton = e("TextButton", {
					ref = confirmBtnRef,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.26059, 0.90909),
					Text = "",
					TextSize = 1,
					AutoButtonColor = false,
					[React.Event.MouseEnter] = if props.ConfirmEnabled then confirmHover.onMouseEnter else nil,
					[React.Event.MouseLeave] = if props.ConfirmEnabled then confirmHover.onMouseLeave else nil,
					[React.Event.Activated] = if props.ConfirmEnabled
						then confirmHover.onActivated(props.OnConfirm)
						else nil,
				}, {
					UIGradient = e("UIGradient", {
						Color = btnGradient,
						Rotation = -140.856,
					}),

					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					Decore = e(Frame, {
						Size = UDim2.new(0.92683, 4, 0.75, 4),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						CornerRadius = UDim.new(0, 3),
						StrokeColor = btnDecoreStroke,
						StrokeThickness = 2,
						StrokeMode = Enum.ApplyStrokeMode.Border,
						StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
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
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(0.92683, 4, 0.75, 4),
						Text = "Confirm",
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
								Color = btnLabelStroke,
							}),
						}),
					}),
				}),
			}),
		},
	})
end

return PartySelectionStatusBar
