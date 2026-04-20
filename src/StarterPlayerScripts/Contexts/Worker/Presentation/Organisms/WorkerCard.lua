--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local XPProgressBar = require(script.Parent.XPProgressBar)
local ActionDropdown = require(script.Parent.ActionDropdown)

local WorkerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.WorkerViewModel)

--[=[
	@class WorkerCard
	Displays a single worker with stats, XP bar, and action dropdowns for role and target assignment.
	@client
]=]

--[=[
	@interface TWorkerCardProps
	@within WorkerCard
	.Worker WorkerViewModel.TWorkerViewModel -- Worker view model
	.LayoutOrder number? -- Layout order in parent list
	.OnAssignRole (roleId: string) -> () -- Callback when role is selected
	.OnOptionsSelect (targetId: string) -> () -- Callback when target is selected
]=]

export type TWorkerCardProps = {
	Worker: WorkerViewModel.TWorkerViewModel,
	LayoutOrder: number?,
	OnAssignRole: (roleId: string) -> (),
	OnOptionsSelect: (targetId: string) -> (),
}

--[=[
	Render a worker card with stats, XP progress, and action dropdowns.
	@within WorkerCard
	@param props TWorkerCardProps -- Component props
	@return React.Element -- Rendered card frame
]=]
local function WorkerCard(props: TWorkerCardProps)
	local worker = props.Worker

	local cardRef = useRef(nil :: Frame?)
	-- Card hover animation on mouse enter/leave
	local hover = useHoverSpring(cardRef, AnimationTokens.Interaction.Card)

	return e("Frame", {
		ref = cardRef,
		Size = UDim2.new(1, 2, 0.09346, 2),
		Position = UDim2.new(0.5, 0, 0.00437, -1),
		AnchorPoint = Vector2.new(0.5, 0.046),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
	}, {
		Inner = e(Frame, {
			Active = true,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			Gradient = GradientTokens.TAB_INACTIVE_GRADIENT,
			GradientRotation = -2,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 1,
			children = {
				TypeInfo = e("Frame", {
					Active = true,
					AnchorPoint = Vector2.new(0.113, 0.507),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.0661, 0.512),
					Size = UDim2.fromScale(0.12, 0.729),
				}, {
					Name = e("TextLabel", {
						Active = true,
						AnchorPoint = Vector2.new(0.45, 0.245),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.new(0.404, 0, 0.156, -1),
						Size = UDim2.new(0.994, 4, 0.49, 4),
						Text = worker.RankLabel,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 25,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, {
						UIStroke = e("UIStroke", {
							Color = Color3.fromRGB(4, 4, 4),
							LineJoinMode = Enum.LineJoinMode.Miter,
							Thickness = 2,
						}),
					}),

					Level = e("TextLabel", {
						Active = true,
						AnchorPoint = Vector2.new(0.281, 0.784),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.137, 0.907),
						Size = UDim2.fromScale(0.657, 0.431),
						Text = worker.LevelLabel,
						TextColor3 = Color3.fromRGB(135, 135, 135),
						TextSize = 21,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				XPBar = e(XPProgressBar, {
					Progress = worker.XPProgress,
					XPLabel = worker.XPLabel,
					AnchorPoint = Vector2.new(0.357, 0.507),
					Position = UDim2.new(0.322, -1, 0.509, 0),
					Size = UDim2.new(0.247, 4, 0.329, 4),
					LayoutOrder = 2,
				}),

				AssignBtn = e(ActionDropdown, {
					TriggerLabel = worker.AssignLabel,
					ButtonGradient = GradientTokens.ASSIGN_BUTTON_GRADIENT,
					ButtonStroke = GradientTokens.ASSIGN_BUTTON_STROKE,
					LabelStroke = Color3.fromRGB(96, 2, 4),
					DropdownStroke = GradientTokens.ASSIGN_DROPDOWN_STROKE,
					SelectedId = worker.AssignedRole,
					Items = worker.RoleItems,
					AnchorPoint = Vector2.new(0.646, 0.507),
					Position = UDim2.fromScale(0.666, 0.512),
					Size = UDim2.fromScale(0.138, 0.729),
					LayoutOrder = 3,
					OnSelect = props.OnAssignRole,
				}),

				OptionsBtn = e(ActionDropdown, {
					TriggerLabel = worker.OptionsLabel,
					ButtonGradient = GradientTokens.OPTIONS_BUTTON_GRADIENT,
					ButtonStroke = GradientTokens.OPTIONS_BUTTON_STROKE,
					LabelStroke = Color3.fromRGB(105, 3, 118),
					DropdownStroke = GradientTokens.OPTIONS_DROPDOWN_STROKE,
					SelectedId = worker.TaskTarget,
					Items = worker.TargetItems,
					AnchorPoint = Vector2.new(0.841, 0.507),
					Position = UDim2.fromScale(0.888, 0.512),
					Size = UDim2.fromScale(0.138, 0.729),
					LayoutOrder = 4,
					OnSelect = props.OnOptionsSelect,
				}),
			},
		}),
	})
end

return WorkerCard
