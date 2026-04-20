--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local QuestHeader = require(script.Parent.Parent.Organisms.QuestHeader)
local QuestTabBar = require(script.Parent.Parent.Organisms.QuestTabBar)
local QuestFooter = require(script.Parent.Parent.Organisms.QuestFooter)

--[=[
	@interface TQuestBoardScreenViewProps
	Props for the quest board screen view component.
	@within QuestBoardScreenView
	.containerRef { current: Frame? } -- Ref for animation container
	.onBack () -> () -- Called when back button is pressed
	.activeTier number -- Currently selected tier filter
	.onTierSelect (tier: number) -> () -- Called when user selects a tier tab
	.expeditionStatusLabel string? -- Optional label for active expedition status
	.onViewExpedition (() -> ())? -- Optional callback to view expedition details
	.scrollChildren { [string]: any } -- Zone entry row components for scrolling list
]=]
type TQuestBoardScreenViewProps = {
	containerRef: { current: Frame? },
	onBack: () -> (),
	activeTier: number,
	onTierSelect: (tier: number) -> (),
	expeditionStatusLabel: string?,
	onViewExpedition: (() -> ())?,
	scrollChildren: { [string]: any },
}

--[=[
	@class QuestBoardScreenView
	View component for the quest board screen.
	Renders header, tier filter tabs, scrollable zone list, and footer.
	@client
]=]

local function QuestBoardScreenView(props: TQuestBoardScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e(QuestHeader, {
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.onBack,
		}),
		TabBar = e(QuestTabBar, {
			Position = UDim2.fromScale(0.5, 0.12779),
			ActiveTier = props.activeTier,
			OnTierSelect = props.onTierSelect,
			ExpeditionStatusLabel = props.expeditionStatusLabel,
			OnViewExpedition = props.onViewExpedition,
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
					}, props.scrollChildren),
				}),
			},
		}),
		Footer = e(QuestFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
		}),
	})
end

return QuestBoardScreenView
