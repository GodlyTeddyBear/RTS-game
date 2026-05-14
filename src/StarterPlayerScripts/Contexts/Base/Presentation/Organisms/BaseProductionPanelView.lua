--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.IconButton)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local BaseProductionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BaseProductionViewModel)
local UnitProductionCard = require(script.Parent.Parent.Molecules.UnitProductionCard)

type TBaseProductionViewData = BaseProductionViewModel.TBaseProductionViewData

export type TBaseProductionPanelViewProps = {
	viewModel: TBaseProductionViewData,
	onClose: () -> (),
	onSelectUnit: (string) -> (),
	onProduce: (string) -> (),
}

local function _CreateUnitCards(props: TBaseProductionPanelViewProps)
	local children = {
		ListLayout = e("UIListLayout", {
			Padding = UDim.new(0, 10),
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for _, cardData in props.viewModel.units do
		children[cardData.unitId] = e(UnitProductionCard, {
			cardData = cardData,
			onSelect = props.onSelectUnit,
			onProduce = props.onProduce,
		})
	end

	return children
end

local function BaseProductionPanelView(props: TBaseProductionPanelViewProps)
	return e(Frame, {
		Size = UDim2.fromScale(0.24, 0.48),
		Position = UDim2.fromScale(0.01, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Colors.NPC.PanelBackground,
		BackgroundTransparency = 0.05,
		Gradient = GradientTokens.PANEL_GRADIENT,
		GradientRotation = 90,
		StrokeColor = GradientTokens.GOLD_STROKE_SUBTLE,
		StrokeThickness = Border.Width.Medium,
		CornerRadius = Border.Radius.LG,
		ClipsDescendants = true,
		ZIndex = 16,
	}, {
		Header = e(Frame, {
			Size = UDim2.fromScale(0.9, 0.16),
			Position = UDim2.fromScale(0.5, 0.1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 17,
		}, {
			Title = e(Text, {
				Size = UDim2.fromScale(0.78, 0.5),
				Position = UDim2.fromScale(0, 0.32),
				AnchorPoint = Vector2.new(0, 0.5),
				Text = props.viewModel.title,
				Variant = "heading",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 18,
			}),
			Subtitle = e(Text, {
				Size = UDim2.fromScale(0.78, 0.3),
				Position = UDim2.fromScale(0, 0.76),
				AnchorPoint = Vector2.new(0, 0.5),
				Text = props.viewModel.subtitle,
				Variant = "caption",
				TextColor3 = Colors.Text.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 18,
			}),
			Close = e(IconButton, {
				Icon = "close",
				Size = UDim2.fromScale(0.16, 0.54),
				Position = UDim2.fromScale(0.94, 0.42),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Variant = "ghost",
				ZIndex = 18,
				[React.Event.Activated] = props.onClose,
			}),
		}),
		Body = e(Frame, {
			Size = UDim2.fromScale(0.9, 0.76),
			Position = UDim2.fromScale(0.5, 0.57),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Colors.Surface.Primary,
			BackgroundTransparency = 0.18,
			CornerRadius = Border.Radius.MD,
			StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
			StrokeThickness = Border.Width.Thin,
			ClipsDescendants = true,
			ZIndex = 17,
		}, {
			Layout = e(VStack, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Gap = 0,
				Padding = 10,
				Align = "Center",
				Justify = "Start",
			}, {
				SectionTitle = e(Text, {
					Size = UDim2.fromScale(0.96, 0.1),
					LayoutOrder = 1,
					Text = "UNITS",
					Variant = "label",
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 18,
				}),
				UnitList = e("ScrollingFrame", {
					Size = UDim2.fromScale(1, 0.86),
					LayoutOrder = 2,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Colors.Accent.Yellow,
					ScrollBarImageTransparency = 0.35,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					ClipsDescendants = true,
					ZIndex = 18,
				}, _CreateUnitCards(props)),
			}),
		}),
	})
end

return BaseProductionPanelView
