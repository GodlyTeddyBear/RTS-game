--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local HStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.HStack)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local BaseProductionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BaseProductionViewModel)

type TUnitProductionCardData = BaseProductionViewModel.TUnitProductionCardData

export type TUnitProductionCardProps = {
	cardData: TUnitProductionCardData,
	onSelect: (string) -> (),
	onProduce: (string) -> (),
}

local function UnitProductionCard(props: TUnitProductionCardProps)
	local cardData = props.cardData
	local strokeColor = if cardData.isSelected then Colors.Accent.Yellow else Colors.Border.Subtle

	return e(Frame, {
		Size = UDim2.fromScale(0.96, 0.28),
		LayoutOrder = cardData.layoutOrder,
		BackgroundColor3 = Colors.Surface.Secondary,
		BackgroundTransparency = 0.12,
		CornerRadius = Border.Radius.MD,
		StrokeColor = ColorSequence.new(strokeColor, strokeColor),
		StrokeThickness = if cardData.isSelected then Border.Width.Medium else Border.Width.Thin,
		ClipsDescendants = true,
	}, {
		Select = e(Button, {
			Text = "",
			Size = UDim2.fromScale(0.72, 1),
			Position = UDim2.fromScale(0, 0),
			AnchorPoint = Vector2.new(0, 0),
			Variant = "ghost",
			DisableAnimations = true,
			[React.Event.Activated] = function()
				props.onSelect(cardData.unitId)
			end,
		}, {
			Content = e(HStack, {
				Size = UDim2.fromScale(0.92, 0.82),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Gap = 10,
				Align = "Center",
				Justify = "Start",
			}, {
				Icon = e(Frame, {
					Size = UDim2.fromScale(0.28, 1),
					LayoutOrder = 1,
					BackgroundColor3 = Colors.Accent.Blue,
					BackgroundTransparency = 0.72,
					CornerRadius = Border.Radius.MD,
					StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
					StrokeThickness = 1,
				}, {
					Label = e(Text, {
						Size = UDim2.fromScale(1, 1),
						Text = string.sub(string.upper(cardData.displayName), 1, 1),
						Variant = "heading",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),
				Details = e(VStack, {
					Size = UDim2.fromScale(0.64, 1),
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					Gap = 1,
					Align = "Start",
					Justify = "Center",
				}, {
					Name = e(Text, {
						Size = UDim2.fromScale(1, 0.34),
						LayoutOrder = 1,
						Text = cardData.displayName,
						Variant = "body",
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Stats = e(Text, {
						Size = UDim2.fromScale(1, 0.28),
						LayoutOrder = 2,
						Text = ("%s / %s"):format(cardData.hpText, cardData.capText),
						Variant = "caption",
						TextColor3 = Colors.Text.Secondary,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					State = e(Text, {
						Size = UDim2.fromScale(1, 0.24),
						LayoutOrder = 3,
						Text = "Offline",
						Variant = "caption",
						TextColor3 = Colors.Text.Muted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),
			}),
		}),
		Produce = e(Button, {
			Size = UDim2.fromScale(0.22, 0.48),
			Position = UDim2.fromScale(0.86, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = "Produce",
			Variant = "ghost",
			DisableAnimations = true,
			TextScaled = true,
			[React.Event.Activated] = function()
				props.onProduce(cardData.unitId)
			end,
		}),
	})
end

return UnitProductionCard
