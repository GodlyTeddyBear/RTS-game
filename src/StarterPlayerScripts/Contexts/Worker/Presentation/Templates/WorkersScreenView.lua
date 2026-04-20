--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.IconButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local WorkerList = require(script.Parent.Parent.Organisms.WorkerList)

--[=[
	@class WorkersScreenView
	View layer for Workers screen. Renders header, worker list, footer with hire button, and overlay container.
	@client
]=]

--[=[
	@interface TWorkersScreenViewProps
	@within WorkersScreenView
	.containerRef { current: Frame? } -- Reference to main container frame
	.workerCount number -- Number of workers for display
	.onGoBack () -> () -- Back button callback
	.workerList { any } -- Array of worker view models
	.onAssignRole (string, string) -> () -- Role assignment callback
	.onOptionsSelect (string, string?) -> () -- Target selection callback
	.hireRef { current: GuiObject? } -- Reference to hire button
	.hireHover { onMouseEnter, onMouseLeave } -- Hover handlers for hire button
	.onHireWorker () -> () -- Hire button callback
	.setOverlayContainer (frame: Frame?) -> () -- Set overlay container frame
]=]

type TWorkersScreenViewProps = {
	containerRef: { current: Frame? },
	workerCount: number,
	onGoBack: () -> (),
	workerList: { any },
	onAssignRole: (string, string) -> (),
	onOptionsSelect: (string, string?) -> (),
	hireRef: { current: GuiObject? },
	hireHover: {
		onMouseEnter: () -> (),
		onMouseLeave: () -> (),
	},
	onHireWorker: () -> (),
	setOverlayContainer: (frame: Frame?) -> (),
}

--[=[
	Render the Workers screen view with header, worker list, and hire footer.
	@within WorkersScreenView
	@param props TWorkersScreenViewProps -- Component props
	@return React.Element -- Rendered screen view
]=]
local function WorkersScreenView(props: TWorkersScreenViewProps)
	return e(React.Fragment, nil, {
		Root = e("Frame", {
			ref = props.containerRef,
			Visible = false,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Header = e(Frame, {
				Position = UDim2.fromScale(0.5, 0.049),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.098),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Gradient = GradientTokens.BAR_GRADIENT,
				StrokeColor = GradientTokens.GOLD_STROKE,
				StrokeThickness = 4,
				StrokeMode = Enum.ApplyStrokeMode.Border,
				StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
				LayoutOrder = 1,
				ClipsDescendants = true,
				children = {
					BackButton = e(IconButton, {
						Icon = "back",
						ImageId = GradientTokens.ICON_BACK_ARROW,
						ImageColor3 = Color3.new(1, 1, 1),
						ImageSize = UDim2.fromScale(0.45, 0.6),
						Position = UDim2.new(0.175, -6, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Size = UDim2.fromScale(0.07, 0.8),
						Variant = "ghost",
						Gradient = GradientTokens.BUTTON_GRADIENT,
						StrokeColor = GradientTokens.GOLD_STROKE,
						StrokeThickness = 2.5,
						CornerRadius = UDim.new(0, 0),
						ClipsDescendants = true,
						[React.Event.Activated] = props.onGoBack,
					}),
					TitleText = e("TextLabel", {
						Text = "Workers",
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 50,
						TextWrapped = true,
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.37917, 0.5),
						Size = UDim2.fromScale(0.167, 0.3),
					}, {
						UIStroke = e("UIStroke", {
							Color = Color3.fromRGB(21, 20, 20),
							LineJoinMode = Enum.LineJoinMode.Miter,
							Thickness = 3,
						}),
					}),
				},
			}),
			TabBar = e(Frame, {
				Position = UDim2.fromScale(0.5, 0.12779),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.06),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Gradient = GradientTokens.BAR_GRADIENT,
				LayoutOrder = 2,
				children = {
					Label = e("TextLabel", {
						Text = "Workers:",
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 25,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.07, 0.5),
						Position = UDim2.fromScale(0.031, 0.49),
						Size = UDim2.fromScale(0.092, 0.49),
					}),
					Amount = e("TextLabel", {
						Text = tostring(props.workerCount),
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 25,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.18, 0.5),
						Position = UDim2.fromScale(0.146, 0.49),
						Size = UDim2.fromScale(0.099, 0.49),
					}),
				},
			}),
			Content = e(Frame, {
				Position = UDim2.fromScale(0.5, 0.53826),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.762),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Gradient = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 18)),
					ColorSequenceKeypoint.new(0.481, Color3.fromRGB(33, 35, 27)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 32, 32)),
				}),
				GradientRotation = -16,
				StrokeColor = GradientTokens.GOLD_STROKE,
				StrokeThickness = 4,
				StrokeMode = Enum.ApplyStrokeMode.Border,
				LayoutOrder = 3,
				ClipsDescendants = true,
				children = {
					InnerStroke = e("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.new(1, 1, 1),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 3,
					}, {
						UIGradient = e("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 80, 0)),
								ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 242, 210)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
							}),
						}),
					}),
					ContainerScroll = e(WorkerList, {
						Workers = props.workerList,
						OnAssignRole = props.onAssignRole,
						OnOptionsSelect = props.onOptionsSelect,
					}),
				},
			}),
			Footer = e(Frame, {
				Position = UDim2.fromScale(0.5, 0.95948),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.081),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Gradient = GradientTokens.BAR_GRADIENT,
				ZIndex = 0,
				children = {
					HireButton = e("TextButton", {
						ref = props.hireRef,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.139, 0.64),
						Text = "",
						TextSize = 1,
						[React.Event.MouseEnter] = props.hireHover.onMouseEnter,
						[React.Event.MouseLeave] = props.hireHover.onMouseLeave,
						[React.Event.Activated] = props.onHireWorker,
					}, {
						UIGradient = e("UIGradient", {
							Color = GradientTokens.GREEN_BUTTON_GRADIENT,
							Rotation = -141,
						}),
						UICorner = e("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),
						Decore = e(Frame, {
							Size = UDim2.fromScale(0.96, 0.75),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							CornerRadius = UDim.new(0, 3),
							StrokeColor = GradientTokens.GREEN_BUTTON_STROKE,
							StrokeThickness = 2,
							StrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						Label = e("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.fromEnum(Enum.Font.GothamBold),
							Interactable = false,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.96, 0.75),
							Text = "Hire Worker",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
							TextStrokeColor3 = Color3.fromRGB(5, 101, 47),
							TextStrokeTransparency = 0,
							TextWrapped = true,
						}),
					}),
				},
			}),
		}),
		DropdownOverlay = e("Frame", {
			ref = props.setOverlayContainer,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			ZIndex = 100,
		}),
	})
end

return WorkersScreenView
