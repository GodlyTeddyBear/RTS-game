--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

local GRADIENT_ROTATION = -141

--[=[
	@interface TItemMetaLabelsProps
	@within ItemMetaLabels
	.Rarity string? -- Rarity tier text
	.RarityColor Color3? -- Rarity text color
	.Category string? -- Category text
	.IsStackable boolean? -- Whether to show stackable info
	.MaxStack number? -- Maximum stack size (shown when IsStackable is true)
]=]
export type TItemMetaLabelsProps = {
	Rarity: string?,
	RarityColor: Color3?,
	Category: string?,
	IsStackable: boolean?,
	MaxStack: number?,
}

--[=[
	@function ItemMetaLabels
	@within ItemMetaLabels
	Renders rarity, category, and optional stackable metadata labels for the
	item detail panel.
	@param props TItemMetaLabelsProps
	@return React.ReactElement
]=]
local function ItemMetaLabels(props: TItemMetaLabelsProps)
	return e(React.Fragment, {}, {
		Rarity = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Interactable = false,
			Position = UDim2.new(0.4771, 0, 0.02326, -4),
			Size = UDim2.new(0.77608, 8, 0.04514, 8),
			Text = props.Rarity or "Common",
			TextColor3 = props.RarityColor or Color3.new(1, 1, 1),
			TextSize = 37,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.new(1, 1, 1),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.SLOT_GRADIENT,
					Rotation = GRADIENT_ROTATION,
				}),
			}),
		}),

		Category = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Interactable = false,
			Position = UDim2.fromScale(0.26972, 0.07524),
			Size = UDim2.fromScale(0.36132, 0.0301),
			Text = props.Category or "Unknown",
			TextColor3 = ColorTokens.Text.OnLight,
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Stackable = if props.IsStackable
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Body,
				Interactable = false,
				Position = UDim2.fromScale(0.31298, 0.11218),
				Size = UDim2.fromScale(0.44784, 0.0301),
				Text = "Stackable (max " .. tostring(props.MaxStack or 1) .. ")",
				TextColor3 = ColorTokens.Text.Secondary,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			else nil,
	})
end

return ItemMetaLabels
