--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local UpgradeRowViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.UpgradeRowViewModel)

export type TUpgradeRowProps = {
	Row: UpgradeRowViewModel.TUpgradeRowViewModel,
	OnBuy: (upgradeId: string) -> (),
	LayoutOrder: number?,
}

local DISABLED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 55, 55)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(75, 75, 75)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 55, 55)),
})
local DISABLED_DECORE_COLOR = Color3.fromRGB(45, 45, 45)
local DISABLED_LABEL_STROKE = Color3.fromRGB(25, 25, 25)

--[=[
	@class UpgradeRow
	Displays a single upgrade entry with current level, effect, and buy button.
	@client
]=]
local function UpgradeRow(props: TUpgradeRowProps)
	local row = props.Row
	local soundActions = useSoundActions()
	local cardRef = useRef(nil :: Frame?)
	local buyBtnRef = useRef(nil :: TextButton?)

	local cardHover = useHoverSpring(cardRef, AnimationTokens.Interaction.Card)
	local buyHover = useHoverSpring(buyBtnRef, {
		HoverScale = AnimationTokens.Interaction.ActionButton.HoverScale,
		PressScale = AnimationTokens.Interaction.ActionButton.PressScale,
		SpringPreset = AnimationTokens.Interaction.ActionButton.SpringPreset,
		Disabled = row.IsMaxed or not row.CanAfford,
	})

	local clickable = not row.IsMaxed and row.CanAfford
	local btnGradient = if clickable then GradientTokens.GREEN_ACTION_GRADIENT else DISABLED_GRADIENT
	local btnDecoreColor = if clickable then GradientTokens.GREEN_ACTION_DECORE_COLOR else DISABLED_DECORE_COLOR
	local btnLabelStroke = if clickable then GradientTokens.GREEN_ACTION_LABEL_STROKE_COLOR else DISABLED_LABEL_STROKE
	local btnText: string
	if row.IsMaxed then
		btnText = "Maxed"
	elseif row.CanAfford then
		btnText = "Buy " .. tostring(row.NextCost) .. "g"
	else
		btnText = "Need " .. tostring(row.NextCost) .. "g"
	end

	local levelText = tostring(row.CurrentLevel) .. "/" .. tostring(row.MaxLevel)

	return e("Frame", {
		ref = cardRef,
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = cardHover.onMouseEnter,
		[React.Event.MouseLeave] = cardHover.onMouseLeave,
	}, {
		Inner = e(Frame, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			Gradient = GradientTokens.TAB_INACTIVE_GRADIENT,
			GradientRotation = -2,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 1,
			children = {
				Info = e("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.03, 0.5),
					Size = UDim2.fromScale(0.6, 0.82),
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 3),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					NameLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 20),
						Text = row.DisplayName,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 18,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, {
						UIStroke = e("UIStroke", {
							Color = Color3.fromRGB(4, 4, 4),
							LineJoinMode = Enum.LineJoinMode.Miter,
							Thickness = 2,
						}),
					}),

					DescLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 14),
						Text = row.Description,
						TextColor3 = Color3.fromRGB(170, 170, 170),
						TextSize = 13,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					EffectLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 14),
						Text = row.EffectText,
						TextColor3 = Color3.fromRGB(140, 200, 140),
						TextSize = 13,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				BuyArea = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.97, 0.5),
					Size = UDim2.fromScale(0.3, 0.82),
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					LevelLabel = e("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 14),
						Text = "Lv " .. levelText,
						TextColor3 = Color3.fromRGB(220, 220, 220),
						TextSize = 13,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),

					BuyBtn = e("TextButton", {
						ref = buyBtnRef,
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 36),
						Text = "",
						TextSize = 1,
						[React.Event.MouseEnter] = buyHover.onMouseEnter,
						[React.Event.MouseLeave] = buyHover.onMouseLeave,
						[React.Event.Activated] = if clickable
							then buyHover.onActivated(function()
								props.OnBuy(row.Id)
							end)
							else function()
								soundActions.playError()
							end,
					}, {
						UIGradient = e("UIGradient", {
							Color = btnGradient,
							Rotation = -3,
						}),
						UICorner = e("UICorner"),
						Decore = e("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.91, 0.82),
						}, {
							UIStroke = e("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								BorderStrokePosition = Enum.BorderStrokePosition.Inner,
								Color = btnDecoreColor,
								Thickness = 2,
							}),
							UICorner = e("UICorner", {
								CornerRadius = UDim.new(0, 4),
							}),
						}),
						Label = e("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothamSSm.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.91, 0.82),
							Text = btnText,
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 13,
							TextWrapped = true,
						}, {
							UIStroke = e("UIStroke", {
								Color = btnLabelStroke,
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 2,
							}),
						}),
					}),
				}),
			},
		}),
	})
end

return UpgradeRow
