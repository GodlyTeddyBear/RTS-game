--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CommissionTierConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionTierConfig)

local e = React.createElement
local useMemo = React.useMemo

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)

local CommissionTabBar = require(script.Parent.Parent.Organisms.CommissionTabBar)
local CommissionFooter = require(script.Parent.Parent.Organisms.CommissionFooter)
local BoardCommissionCard = require(script.Parent.Parent.Organisms.BoardCommissionCard)
local ActiveCommissionCard = require(script.Parent.Parent.Organisms.ActiveCommissionCard)
local CommissionBoardScreenView = require(script.Parent.CommissionBoardScreenView)

local useCommissionState = require(script.Parent.Parent.Parent.Application.Hooks.useCommissionState)
local useCommissionBoardController =
	require(script.Parent.Parent.Parent.Application.Hooks.useCommissionBoardController)
local useInventoryState =
	require(script.Parent.Parent.Parent.Parent.Inventory.Application.Hooks.useInventoryState)

local BoardCommissionViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.BoardCommissionViewModel)
local ActiveCommissionViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.ActiveCommissionViewModel)

-- Staggered wrapper for board cards; only renders when index is within visible range
type TStaggeredBoardCardProps = {
	Commission: BoardCommissionViewModel.TBoardCommissionVM,
	OnAccept: (commissionId: string) -> (),
	LayoutOrder: number,
	Index: number,
}

local function StaggeredBoardCard(props: TStaggeredBoardCardProps)
	-- Guard visibility with staggered mount to control animation timing
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(BoardCommissionCard, {
		Commission = props.Commission,
		OnAccept = props.OnAccept,
		LayoutOrder = props.LayoutOrder,
	})
end

-- Staggered wrapper for active cards; only renders when index is within visible range
type TStaggeredActiveCardProps = {
	Commission: ActiveCommissionViewModel.TActiveCommissionVM,
	OnDeliver: (commissionId: string) -> (),
	OnAbandon: (commissionId: string) -> (),
	LayoutOrder: number,
	Index: number,
}

local function StaggeredActiveCard(props: TStaggeredActiveCardProps)
	-- Guard visibility with staggered mount to control animation timing
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(ActiveCommissionCard, {
		Commission = props.Commission,
		OnDeliver = props.OnDeliver,
		OnAbandon = props.OnAbandon,
		LayoutOrder = props.LayoutOrder,
	})
end

--[=[
	@function CommissionBoardScreen
	Main commission board screen. Shows available/active commissions with tier progression.
	@return Instance -- React frame element
	@tag Template
]=]
local function CommissionBoardScreen()
	local anim = useScreenTransition("Standard")
	local commissionState = useCommissionState()
	local inventoryState = useInventoryState()
	local controller = useCommissionBoardController()
	local navActions = useNavigationActions()

	-- Safe access: provide defaults if state hasn't loaded yet
	local board = (commissionState and commissionState.Board) or {}
	local active = (commissionState and commissionState.Active) or {}
	local tokens = (commissionState and commissionState.Tokens) or 0
	local currentTier = (commissionState and commissionState.CurrentTier) or 1

	-- Resolve tier display from config; fallback to numeric tier label if not found
	local currentTierConfig = CommissionTierConfig[currentTier]
	local tierLabel = currentTierConfig and currentTierConfig.Label or ("Tier " .. currentTier)

	-- Check if next tier exists and whether player can afford it
	local nextTierConfig = CommissionTierConfig[currentTier + 1]
	local hasNextTier = nextTierConfig ~= nil
	local canUnlock = hasNextTier and tokens >= nextTierConfig.UnlockCost
	local nextTierLabel = if hasNextTier
		then nextTierConfig.Label .. " (" .. nextTierConfig.UnlockCost .. " Tokens)"
		else "Max Tier"

	-- Transform raw commission data into view models (memoized to prevent unnecessary recalculation)
	local boardVMs = useMemo(function()
		return BoardCommissionViewModel.fromBoardList(board, #active)
	end, { board, active })

	local activeVMs = useMemo(function()
		return ActiveCommissionViewModel.fromActiveList(active, inventoryState)
	end, { active, inventoryState })

	-- Determine which tab is active and item count (used to center empty state)
	local activeTab = controller.activeTab
	local itemCount = if activeTab == "available" then #boardVMs else #activeVMs

	-- Build scroll content with list layout and conditional empty state
	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			-- Center empty state; top-align when items exist
			VerticalAlignment = if itemCount == 0
				then Enum.VerticalAlignment.Center
				else Enum.VerticalAlignment.Top,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
		}),
	}

	-- Populate scroll content based on active tab
	if activeTab == "available" then
		if #boardVMs == 0 then
			-- Show empty state when no board commissions
			scrollChildren["EmptyText"] = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.1),
				Text = "No commissions available. Check back soon!",
				TextColor3 = Color3.fromRGB(150, 150, 150),
				TextSize = 18,
				TextWrapped = true,
			})
		else
			-- Build board commission cards with staggered mount animation
			for i, vm in ipairs(boardVMs) do
				scrollChildren["Board_" .. vm.Id] = e(StaggeredBoardCard, {
					Commission = vm,
					OnAccept = controller.onAccept,
					LayoutOrder = i,
					Index = i,
				})
			end
		end
	else
		if #activeVMs == 0 then
			-- Show empty state when no active commissions
			scrollChildren["EmptyText"] = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.1),
				Text = "No active commissions. Accept some from the board!",
				TextColor3 = Color3.fromRGB(150, 150, 150),
				TextSize = 18,
				TextWrapped = true,
			})
		else
			-- Build active commission cards with staggered mount animation
			for i, vm in ipairs(activeVMs) do
				scrollChildren["Active_" .. vm.Id] = e(StaggeredActiveCard, {
					Commission = vm,
					OnDeliver = controller.onDeliver,
					OnAbandon = controller.onAbandon,
					LayoutOrder = i,
					Index = i,
				})
			end
		end
	end

	return e(CommissionBoardScreenView, {
		containerRef = anim.containerRef,
		onBack = navActions.goBack,
		tierLabel = tierLabel,
		tokens = tokens,
		activeTab = activeTab,
		onTabSelect = controller.onTabSelect,
		onRefresh = controller.onRefresh,
		scrollChildren = scrollChildren,
		canUnlock = canUnlock,
		hasNextTier = hasNextTier,
		nextTierLabel = nextTierLabel,
		onUnlock = controller.onUnlock,
	})
end

return CommissionBoardScreen
