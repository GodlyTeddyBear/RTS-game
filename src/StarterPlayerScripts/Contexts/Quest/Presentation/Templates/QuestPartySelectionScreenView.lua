--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local PartySelectionStatusBar = require(script.Parent.Parent.Organisms.PartySelectionStatusBar)
local QuestFooter = require(script.Parent.Parent.Organisms.QuestFooter)

--[=[
	@interface TQuestPartySelectionScreenViewProps
	Props for the party selection screen view component.
	@within QuestPartySelectionScreenView
	.containerRef { current: Frame? } -- Ref for animation container
	.screenTitle string -- Screen title (includes zone name)
	.onBack () -> () -- Called when back button is pressed
	.selectedCount number -- Number of currently selected adventurers
	.partySizeLabel string -- Formatted party size requirement
	.onConfirm () -> () -- Called when confirm button is pressed
	.confirmEnabled boolean -- Whether confirm button is enabled
	.adventurerRows { [string]: any } -- Adventurer row components for list
]=]
type TQuestPartySelectionScreenViewProps = {
	containerRef: { current: Frame? },
	screenTitle: string,
	onBack: () -> (),
	selectedCount: number,
	partySizeLabel: string,
	onConfirm: () -> (),
	confirmEnabled: boolean,
	adventurerRows: { [string]: any },
}

--[=[
	@class QuestPartySelectionScreenView
	View component for party selection screen.
	Displays header, party size status, adventurer list, and confirmation button.
	@client
]=]

local function QuestPartySelectionScreenView(props: TQuestPartySelectionScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e(ScreenHeader, {
			Title = props.screenTitle,
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.onBack,
		}),
		TabBar = e(PartySelectionStatusBar, {
			SelectedCount = props.selectedCount,
			PartySizeLabel = props.partySizeLabel,
			OnConfirm = props.onConfirm,
			ConfirmEnabled = props.confirmEnabled,
			Position = UDim2.fromScale(0.5, 0.12779),
			ZIndex = 1,
		}),
		Content = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.53826),
			Size = UDim2.fromScale(1, 0.76172),
			ZIndex = 2,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.LIST_CONTAINER_GRADIENT,
			GradientRotation = -16,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			ClipsDescendants = true,
			children = {
				ContainerScroll = e("ScrollingFrame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.97708, 0.96026),
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
					ClipsDescendants = true,
				}, {
					UIStroke = e("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.new(1, 1, 1),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 3,
					}, {
						UIGradient = e("UIGradient", {
							Color = GradientTokens.GOLD_STROKE_SUBTLE,
						}),
					}),
					Content = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
					}, props.adventurerRows),
				}),
			},
		}),
		Footer = e(QuestFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
		}),
	})
end

return QuestPartySelectionScreenView
