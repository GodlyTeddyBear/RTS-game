--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useTaskState = require(script.Parent.Parent.Parent.Application.Hooks.useTaskState)
local useTaskActions = require(script.Parent.Parent.Parent.Application.Hooks.useTaskActions)
local TaskLogViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.TaskLogViewModel)
local TaskCard = require(script.Parent.Parent.Organisms.TaskCard)

local function _AppendSection(
	children: { [string]: any },
	title: string,
	tasks: { any },
	startOrder: number,
	onClaim: (string) -> ()
): number
	if #tasks == 0 then
		return startOrder
	end

	children[title .. "_Header"] = e("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold),
		LayoutOrder = startOrder,
		Size = UDim2.fromScale(0.94, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local order = startOrder + 1
	for _, taskVM in ipairs(tasks) do
		children[title .. "_" .. taskVM.TaskId] = e(TaskCard, {
			Task = taskVM,
			LayoutOrder = order,
			OnClaim = onClaim,
		})
		order += 1
	end

	return order
end

local function TaskLogScreen()
	local anim = useScreenTransition("Standard")
	local navigationActions = useNavigationActions()
	local taskState = useTaskState()
	local actions = useTaskActions()

	local viewModel = React.useMemo(function()
		return TaskLogViewModel.fromTaskState(taskState)
	end, { taskState })

	local scrollChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = if viewModel.IsEmpty then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
		}),
	}

	if viewModel.IsEmpty then
		scrollChildren.Empty = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			Size = UDim2.fromScale(0.8, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = "No active tasks.",
			TextColor3 = Color3.fromRGB(190, 195, 204),
			TextSize = 20,
			TextWrapped = true,
		})
	else
		local order = 1
		order = _AppendSection(scrollChildren, "Ready to Claim", viewModel.ClaimableTasks, order, actions.claimTaskReward)
		_AppendSection(scrollChildren, "Active Tasks", viewModel.ActiveTasks, order + 1, actions.claimTaskReward)
	end

	return e("Frame", {
		ref = anim.containerRef,
		BackgroundColor3 = Color3.fromRGB(17, 19, 24),
		Size = UDim2.fromScale(1, 1),
	}, {
		Header = e(ScreenHeader, {
			Title = "Tasks",
			OnBack = navigationActions.goBack,
		}),
		Scroll = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromScale(0.5, 0.56),
			ScrollBarThickness = 6,
			Size = UDim2.fromScale(0.9, 0.78),
		}, scrollChildren),
	})
end

return TaskLogScreen
