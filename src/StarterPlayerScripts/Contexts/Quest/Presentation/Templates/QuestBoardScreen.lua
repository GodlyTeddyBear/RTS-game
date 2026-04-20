--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

local QuestHeader = require(script.Parent.Parent.Organisms.QuestHeader)
local QuestTabBar = require(script.Parent.Parent.Organisms.QuestTabBar)
local QuestEntryRow = require(script.Parent.Parent.Organisms.QuestEntryRow)
local QuestBoardScreenView = require(script.Parent.QuestBoardScreenView)

local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)

local useQuestBoardController = require(script.Parent.Parent.Parent.Application.Hooks.useQuestBoardController)

-- Wrapper that only renders after a staggered delay for list entry animations.
local function StaggeredQuestEntryRow(props: QuestEntryRow.TQuestEntryRowProps & { Index: number })
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(QuestEntryRow, props)
end

--[=[
	@class QuestBoardScreen
	Screen for browsing and selecting quests by difficulty tier.
	Displays available zones with stats and allows navigation to party selection.
	@client
]=]
local function QuestBoardScreen()
	local anim = useScreenTransition("Standard")
	local ctrl = useQuestBoardController()

	-- Build scroll content
	local scrollChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
			PaddingTop = UDim.new(0.015, 0),
			PaddingBottom = UDim.new(0.015, 0),
		}),
	}

	if #ctrl.filteredZoneVMs == 0 then
		scrollChildren["EmptyText"] = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = "No quests available for this tier.",
			TextColor3 = Color3.fromRGB(150, 150, 150),
			TextSize = 18,
			TextWrapped = true,
		})
	else
		for i, vm in ipairs(ctrl.filteredZoneVMs) do
			scrollChildren["Zone_" .. vm.ZoneId] = e(StaggeredQuestEntryRow, {
				ZoneId = vm.ZoneId,
				DisplayName = vm.DisplayName,
				TierLabel = vm.TierLabel,
				RecommendedATKLabel = vm.RecommendedATKLabel,
				RecommendedDEFLabel = vm.RecommendedDEFLabel,
				WaveCountLabel = vm.WaveCountLabel,
				Description = vm.Description,
				IsExpeditionActive = ctrl.isExpeditionActive,
				IsLocked = not vm.IsUnlocked,
				LayoutOrder = i,
				Index = i,
				OnAccept = ctrl.onAcceptZone,
			})
		end
	end

	return e(QuestBoardScreenView, {
		containerRef = anim.containerRef,
		onBack = ctrl.onBack,
		activeTier = ctrl.activeTier,
		onTierSelect = ctrl.onTierSelect,
		expeditionStatusLabel = if ctrl.isExpeditionActive then ctrl.expeditionVM.StatusLabel .. " →" else nil,
		onViewExpedition = if ctrl.isExpeditionActive then ctrl.onViewExpedition else nil,
		scrollChildren = scrollChildren,
	})
end

return QuestBoardScreen
