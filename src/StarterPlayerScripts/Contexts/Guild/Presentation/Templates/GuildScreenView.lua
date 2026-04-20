--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local GuildConfig = require(ReplicatedStorage.Contexts.Guild.Config.GuildConfig)

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local GuildTabBar = require(script.Parent.Parent.Organisms.GuildTabBar)
local GuildDetailPanel = require(script.Parent.Parent.Organisms.GuildDetailPanel)
local GuildFooter = require(script.Parent.Parent.Organisms.GuildFooter)

type TGuildScreenViewProps = {
	containerRef: { current: Frame? },
	onBack: () -> (),
	gold: number,
	rosterSize: number,
	activeTab: string,
	onTabSelect: (tab: string) -> (),
	gridChildren: { [string]: any },
	detailProps: { [string]: any },
}

local function GuildScreenView(props: TGuildScreenViewProps)
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
			Title = "Guild",
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.onBack,
		}),
		TabBar = e(GuildTabBar, {
			Position = UDim2.fromScale(0.5, 0.12779),
			Gold = props.gold,
			RosterCount = props.rosterSize,
			MaxRoster = GuildConfig.MAX_ROSTER_SIZE,
			ActiveTab = props.activeTab,
			OnTabSelect = props.onTabSelect,
		}),
		Content = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.53826),
			Size = UDim2.fromScale(1, 0.76172),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.LIST_CONTAINER_GRADIENT,
			GradientRotation = -16,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			ClipsDescendants = true,
			children = {
				Container = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.33472, 0.5),
					Size = UDim2.fromScale(0.64583, 0.96154),
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
					ContainerScroll = e("ScrollingFrame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.49933),
						Size = UDim2.fromScale(0.95699, 0.96667),
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
						ClipsDescendants = true,
					}, props.gridChildren),
				}),
				DetailPanel = e(GuildDetailPanel, props.detailProps),
			},
		}),
		Footer = e(GuildFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
		}),
	})
end

return GuildScreenView
