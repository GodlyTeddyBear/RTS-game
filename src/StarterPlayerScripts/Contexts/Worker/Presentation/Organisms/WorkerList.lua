--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)

local WorkerCard = require(script.Parent.WorkerCard)
local WorkerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.WorkerViewModel)

--[=[
	@class WorkerList
	Scrollable list of worker cards with staggered entrance animation.
	@client
]=]

--[=[
	@interface TWorkerListProps
	@within WorkerList
	.Workers { WorkerViewModel.TWorkerViewModel } -- Array of worker view models
	.OnAssignRole (workerId: string, roleId: string) -> () -- Callback for role assignment
	.OnOptionsSelect (workerId: string, roleKey: string, targetId: string) -> () -- Callback for target selection
]=]

export type TWorkerListProps = {
	Workers: { WorkerViewModel.TWorkerViewModel },
	OnAssignRole: (workerId: string, roleId: string) -> (),
	OnOptionsSelect: (workerId: string, roleKey: string, targetId: string) -> (),
}

-- Internal component that applies staggered mount animation per card
type TStaggeredWorkerCardProps = {
	Worker: WorkerViewModel.TWorkerViewModel,
	Index: number,
	OnAssignRole: (roleId: string) -> (),
	OnOptionsSelect: (targetId: string) -> (),
}

-- Render a worker card with staggered mount animation
local function StaggeredWorkerCard(props: TStaggeredWorkerCardProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)

	if not isVisible then
		return nil
	end

	return e(WorkerCard, {
		Worker = props.Worker,
		LayoutOrder = props.Index,
		OnAssignRole = props.OnAssignRole,
		OnOptionsSelect = props.OnOptionsSelect,
	})
end

--[=[
	Render a scrollable list of worker cards with staggered entrance animation.
	@within WorkerList
	@param props TWorkerListProps -- Component props
	@return React.Element -- Rendered scrolling frame
]=]
local function WorkerList(props: TWorkerListProps)
	local workers = props.Workers
	local workerCount = #workers

	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = if workerCount == 0
				then Enum.VerticalAlignment.Center
				else Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.015, 0),
			PaddingRight = UDim.new(0.015, 0),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	}

	if workerCount == 0 then
		scrollChildren["EmptyText"] = e(Text, {
			Text = "No workers yet. Hire your first worker!",
			Variant = "body",
			Size = UDim2.fromScale(1, 0.08),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	else
		for i, vm in ipairs(workers) do
			scrollChildren["Worker_" .. vm.Id] = e(StaggeredWorkerCard, {
				Worker = vm,
				Index = i,
				OnAssignRole = function(roleId: string)
					props.OnAssignRole(vm.Id, roleId)
				end,
				OnOptionsSelect = function(targetId: string)
					props.OnOptionsSelect(vm.Id, vm.OptionsSelectRole, targetId)
				end,
			})
		end
	end

	return e("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.977, 0.96),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
		ClipsDescendants = true,
	}, scrollChildren)
end

return WorkerList
