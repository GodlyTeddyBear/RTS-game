--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)
local useGold = require(script.Parent.Parent.Parent.Parent.Shop.Application.Hooks.useGold)

local UpgradeRow = require(script.Parent.Parent.Organisms.UpgradeRow)
local UpgradeScreenView = require(script.Parent.UpgradeScreenView)
local useUpgrades = require(script.Parent.Parent.Parent.Application.Hooks.useUpgrades)
local useUpgradeActions = require(script.Parent.Parent.Parent.Application.Hooks.useUpgradeActions)
local UpgradeRowViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.UpgradeRowViewModel)

type TStaggeredRowProps = UpgradeRow.TUpgradeRowProps & { Index: number }

local function StaggeredUpgradeRow(props: TStaggeredRowProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(UpgradeRow, props)
end

--[=[
	@class UpgradeScreen
	Root screen component for the upgrade feature. Renders a scrollable list of upgrades with buy buttons.
	@client
]=]
local function UpgradeScreen()
	local anim = useScreenTransition("Standard")
	local levels = useUpgrades()
	local currentGold = useGold()
	local upgradeActions = useUpgradeActions()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()

	local rows = UpgradeRowViewModel.all(levels, currentGold)
	local rowCount = #rows

	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = if rowCount == 0 then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
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

	if rowCount == 0 then
		scrollChildren["EmptyText"] = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = "No upgrades available.",
			TextColor3 = Color3.fromRGB(150, 150, 150),
			TextSize = 18,
			TextWrapped = true,
		})
	else
		for i, vm in ipairs(rows) do
			scrollChildren["Upgrade_" .. vm.Id] = e(StaggeredUpgradeRow, {
				Row = vm,
				OnBuy = function(upgradeId: string)
					upgradeActions.purchase(upgradeId)
				end,
				LayoutOrder = i,
				Index = i,
			})
		end
	end

	return e(UpgradeScreenView, {
		containerRef = anim.containerRef,
		upgradeCount = rowCount,
		scrollChildren = scrollChildren,
		onBack = function()
			soundActions.playMenuClose("Upgrades")
			navActions.goBack()
		end,
	})
end

return UpgradeScreen
