--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local Spacing = require(script.Parent.Parent.Parent.Parent.App.Config.SpacingTokens)
local useAnimatedVisibility = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useAnimatedVisibility)
local usePlacementCursorActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.usePlacementCursorActions)

local usePlacementPaletteHud = require(script.Parent.Parent.Parent.Application.Hooks.usePlacementPaletteHud)
local StructureCard = require(script.Parent.Parent.Molecules.StructureCard)

type TStructureCardData = usePlacementPaletteHud.TStructureCardData

export type TPlacementPaletteProps = {
	onStructureSelected: ((string) -> ())?,
}

local function PlacementPalette(props: TPlacementPaletteProps)
	local paletteHud = usePlacementPaletteHud()
	local placementCursorActions = usePlacementCursorActions()
	local selectedType, setSelectedType = React.useState(nil :: string?)
	local visibility = useAnimatedVisibility(paletteHud.isVisible, {
		Mode = "slideRight",
		SpringPreset = "Smooth",
	})

	React.useEffect(function()
		local connection = placementCursorActions.onCancelled(function()
			setSelectedType(nil)
		end)

		return function()
			connection:Disconnect()
		end
	end, { placementCursorActions })

	if not visibility.shouldRender then
		return nil
	end

	local onStructureSelected = props.onStructureSelected or function(_structureType: string)
	end

	local function _HandleStructureSelected(cardData: TStructureCardData)
		onStructureSelected(cardData.structureType)
		setSelectedType(if selectedType == cardData.structureType then nil else cardData.structureType)
	end

	return e(Frame, {
		ref = visibility.containerRef,
		Size = UDim2.fromScale(0.22, 0.44),
		Position = UDim2.fromScale(0.01, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Colors.Surface.Primary,
		BackgroundTransparency = 0.08,
		StrokeColor = ColorSequence.new(Colors.Accent.Yellow, Colors.Accent.Yellow),
		StrokeThickness = Border.Width.Medium,
		CornerRadius = Border.Radius.LG,
		ClipsDescendants = true,
	}, {
		Layout = e(VStack, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Gap = Spacing.SM,
			Padding = Spacing.MD,
			Align = "Start",
			Justify = "Start",
		}, {
			Title = e(Text, {
				Size = UDim2.fromScale(1, 0.1),
				Text = "BUILD",
				Variant = "heading",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Body = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 0.84),
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
			}, (function()
				local children = {
					ListLayout = e("UIListLayout", {
						Padding = UDim.new(0, Spacing.SM),
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}
				for _, cardData in paletteHud.structures do
					children[cardData.structureType] = e(StructureCard, {
						cardData = cardData,
						isSelected = selectedType == cardData.structureType,
						onSelect = function(_structureType: string)
							_HandleStructureSelected(cardData)
						end,
						LayoutOrder = cardData.layoutOrder,
					})
				end
				return children
			end)()),
		}),
	})
end

return PlacementPalette
