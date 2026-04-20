--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local CommissionTabBar = require(script.Parent.Parent.Organisms.CommissionTabBar)
local CommissionFooter = require(script.Parent.Parent.Organisms.CommissionFooter)

--[=[
	@interface TCommissionBoardScreenViewProps
	Props for CommissionBoardScreenView.
	.containerRef { current: Frame? } -- Ref to main container for animation
	.onBack () -> () -- Callback for back button
	.tierLabel string -- Current tier label
	.tokens number -- Current token count
	.activeTab string -- Currently selected tab
	.onTabSelect (tab: string) -> () -- Callback for tab selection
	.onRefresh () -> () -- Callback for refresh button
	.scrollChildren { [string]: any } -- Children for scroll content frame
	.canUnlock boolean -- Whether unlock is available
	.hasNextTier boolean -- Whether next tier exists
	.nextTierLabel string -- Label for next tier
	.onUnlock () -> () -- Callback for unlock button
]=]

type TCommissionBoardScreenViewProps = {
	containerRef: { current: Frame? },
	onBack: () -> (),
	tierLabel: string,
	tokens: number,
	activeTab: string,
	onTabSelect: (tab: string) -> (),
	onRefresh: () -> (),
	scrollChildren: { [string]: any },
	canUnlock: boolean,
	hasNextTier: boolean,
	nextTierLabel: string,
	onUnlock: () -> (),
}

--[=[
	Layout view for the commission board screen. Assembles header, tab bar, content area, and footer.
	@within CommissionBoardScreenView
	@param props TCommissionBoardScreenViewProps
	@return Instance -- React frame element
]=]
local function CommissionBoardScreenView(props: TCommissionBoardScreenViewProps)
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
			Title = "Commission",
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.onBack,
		}),
		TabBar = e(CommissionTabBar, {
			Position = UDim2.fromScale(0.5, 0.12779),
			TierLabel = props.tierLabel,
			Tokens = props.tokens,
			ActiveTab = props.activeTab,
			OnTabSelect = props.onTabSelect,
			OnRefresh = props.onRefresh,
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
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.97708, 0.96026),
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
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -12, 1, -10),
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
						ClipsDescendants = true,
					}, props.scrollChildren),
				}),
			},
		}),
		Footer = e(CommissionFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
			CanUnlock = props.canUnlock,
			HasNextTier = props.hasNextTier,
			NextTierLabel = props.nextTierLabel,
			OnUnlock = props.onUnlock,
		}),
	})
end

return CommissionBoardScreenView
