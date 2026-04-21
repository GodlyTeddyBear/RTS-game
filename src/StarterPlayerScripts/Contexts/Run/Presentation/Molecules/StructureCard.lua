--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local usePlacementPaletteHud = require(script.Parent.Parent.Parent.Application.Hooks.usePlacementPaletteHud)

type TStructureCardData = usePlacementPaletteHud.TStructureCardData

export type TStructureCardProps = {
	cardData: TStructureCardData,
	isSelected: boolean,
	onSelect: (string) -> (),
	LayoutOrder: number?,
}

local function StructureCard(props: TStructureCardProps)
	local strokeColor = if props.isSelected then Colors.Accent.Yellow else Colors.Border.Subtle
	local costColor = if props.cardData.canAfford then Colors.Text.Secondary else Colors.Semantic.Error

	return e(Button, {
		Text = "",
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder,
		Variant = "secondary",
		ClipsDescendants = true,
		StrokeColor = ColorSequence.new(strokeColor, strokeColor),
		StrokeThickness = if props.isSelected then Border.Width.Medium else Border.Width.Thin,
		[React.Event.Activated] = function()
			props.onSelect(props.cardData.structureType)
		end,
		}, {
			Icon = e(Frame, {
				Size = UDim2.fromScale(1, 0.62),
				Position = UDim2.fromScale(0, 0),
				AnchorPoint = Vector2.new(0, 0),
				BackgroundColor3 = Colors.Accent.Yellow,
				BackgroundTransparency = 0.82,
				ClipsDescendants = true,
				ZIndex = 2,
				CornerRadius = Border.Radius.MD,
		}, {
			IconLabel = e(Text, {
				Size = UDim2.fromScale(1, 1),
				Text = string.sub(string.upper(props.cardData.displayName), 1, 1),
				Variant = "heading",
				TextColor3 = Colors.Text.Primary,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
		Content = e(VStack, {
			Size = UDim2.fromScale(1, 0.34),
			Position = UDim2.fromScale(0, 0.66),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Gap = 0,
			Align = "Center",
			Justify = "Start",
		}, {
			Name = e(Text, {
				Size = UDim2.fromScale(1, 0.42),
				LayoutOrder = 1,
				Text = props.cardData.displayName,
				Variant = "body",
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Cost = e(Text, {
				Size = UDim2.fromScale(1, 0.34),
				LayoutOrder = 2,
				Text = string.format("%d E", props.cardData.energyCost),
				Variant = "caption",
				TextColor3 = costColor,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	})
end

return StructureCard
