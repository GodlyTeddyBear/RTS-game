--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local GuildConfig = require(ReplicatedStorage.Contexts.Guild.Config.GuildConfig)

local e = React.createElement
local useMemo = React.useMemo

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local GuildTabBar = require(script.Parent.Parent.Organisms.GuildTabBar)
local GuildSlotCell = require(script.Parent.Parent.Organisms.GuildSlotCell)
local GuildScreenView = require(script.Parent.GuildScreenView)

local useGuildState = require(script.Parent.Parent.Parent.Application.Hooks.useGuildState)
local useGuildScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useGuildScreenController)
local useGold = require(script.Parent.Parent.Parent.Parent.Shop.Application.Hooks.useGold)

local AdventurerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.AdventurerViewModel)
local HireRosterViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.HireRosterViewModel)

-- Staggered wrapper so useStaggeredMount can be called per-cell
type TStaggeredSlotCellProps = {
	Name: string,
	CostDisplay: string?,
	IsSelected: boolean,
	OnSelect: () -> (),
	LayoutOrder: number,
	Index: number,
}

local function StaggeredGuildSlotCell(props: TStaggeredSlotCellProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.Grid)

	if not isVisible then
		return nil
	end

	return e(GuildSlotCell, {
		Name = props.Name,
		CostDisplay = props.CostDisplay,
		IsSelected = props.IsSelected,
		OnSelect = props.OnSelect,
		LayoutOrder = props.LayoutOrder,
	})
end

local function GuildScreen()
	local anim = useScreenTransition("Standard")
	local adventurers = useGuildState()
	local gold = useGold()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()
	local controller = useGuildScreenController()

	local rosterSize = useMemo(function()
		-- Count adventurers in guild (needed for capacity display)
		local count = 0
		for _ in pairs(adventurers) do
			count = count + 1
		end
		return count
	end, { adventurers } :: { any })

	local adventurerVMs = useMemo(function()
		-- Transform adventurers to ViewModels and sort by name for consistent display
		local vms = {}
		for _, adv in pairs(adventurers) do
			table.insert(vms, AdventurerViewModel.fromAdventurer(adv))
		end
		table.sort(vms, function(a, b)
			return a.TypeLabel < b.TypeLabel
		end)
		return vms
	end, { adventurers } :: { any })

	local hireCatalog = useMemo(function()
		return HireRosterViewModel.buildCatalog(gold, rosterSize)
	end, { gold, rosterSize } :: { any })

	local gridChildren: { [string]: any } = useMemo(function()
		local children: { [string]: any } = {
			UIGridLayout = e("UIGridLayout", {
				CellSize = UDim2.fromScale(0.168, 0.2069),
				CellPadding = UDim2.fromScale(0.02, 0.02),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				FillDirectionMaxCells = 5,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0.02, 0),
				PaddingRight = UDim.new(0.02, 0),
				PaddingTop = UDim.new(0.015, 0),
				PaddingBottom = UDim.new(0.015, 0),
			}),
		}

		-- Render grid contents based on active tab
		if controller.activeTab == "roster" then
			if #adventurerVMs == 0 then
				-- Empty state: no adventurers hired yet
				children["EmptyText"] = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.1),
					Text = "No adventurers hired yet. Visit the Hire tab!",
					TextColor3 = Color3.fromRGB(150, 150, 150),
					TextSize = 18,
					TextWrapped = true,
				})
			else
				-- Render roster cells with staggered mount animation
				for i, vm in ipairs(adventurerVMs) do
					local isSelected = controller.selectedItem ~= nil and controller.selectedItem.Id == vm.Id
					children["Adv_" .. vm.Id] = e(StaggeredGuildSlotCell, {
						Name = vm.TypeLabel,
						IsSelected = isSelected,
						OnSelect = function()
							controller.onSelectRosterItem(vm)
						end,
						LayoutOrder = i,
						Index = i,
					})
				end
			end
		elseif controller.activeTab == "hire" then
			if #hireCatalog == 0 then
				-- Empty state: no adventurers available for hire
				children["EmptyText"] = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.1),
					Text = "No adventurers available for hire.",
					TextColor3 = Color3.fromRGB(150, 150, 150),
					TextSize = 18,
					TextWrapped = true,
				})
			else
				-- Render hire catalog cells with cost display and staggered animation
				for i, vm in ipairs(hireCatalog) do
					local isSelected = controller.selectedItem ~= nil
						and controller.selectedItem.Type == vm.Type
						and controller.selectedItem.Tab == "hire"
					children["Hire_" .. vm.Type] = e(StaggeredGuildSlotCell, {
						Name = vm.DisplayName,
						CostDisplay = vm.CostDisplay,
						IsSelected = isSelected,
						OnSelect = function()
							controller.onSelectHireItem(vm)
						end,
						LayoutOrder = i,
						Index = i,
					})
				end
			end
		end

		return children
	end, { controller.activeTab, controller.selectedItem, adventurerVMs, hireCatalog } :: { any })

	return e(GuildScreenView, {
		containerRef = anim.containerRef,
		onBack = function()
			soundActions.playMenuClose("Guild")
			navActions.goBack()
		end,
		gold = gold,
		rosterSize = rosterSize,
		activeTab = controller.activeTab,
		onTabSelect = controller.onTabSelect,
		gridChildren = gridChildren,
		detailProps = controller.detailProps,
	})
end

return GuildScreen
