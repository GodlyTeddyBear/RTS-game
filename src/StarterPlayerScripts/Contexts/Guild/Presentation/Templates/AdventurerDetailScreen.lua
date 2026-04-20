--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useMemo = React.useMemo

local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)

local AdventurerDetailScreenView = require(script.Parent.AdventurerDetailScreenView)

local useGuildState = require(script.Parent.Parent.Parent.Application.Hooks.useGuildState)
local useGuildActions = require(script.Parent.Parent.Parent.Application.Hooks.useGuildActions)
local useAdventurerDetailScreenController =
	require(script.Parent.Parent.Parent.Application.Hooks.useAdventurerDetailScreenController)
-- TODO: Move to a shared App-level atom once a CurrencyAtom or PlayerAtom exists
local useInventoryState =
	require(script.Parent.Parent.Parent.Parent.Inventory.Application.Hooks.useInventoryState)
local useNavigationActions =
	require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local AdventurerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.AdventurerViewModel)
local AdventurerEquipmentLayoutViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.AdventurerEquipmentLayoutViewModel)

local function AdventurerDetailScreen(props: { params: { [string]: any }? })
	local anim = useScreenTransition("Standard")
	local adventurers = useGuildState()
	local guildActions = useGuildActions()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()

	local adventurerId = props.params and props.params.adventurerId or nil
	local safeAdventurerId = adventurerId or ""
	local adventurer = if adventurerId then adventurers[adventurerId] else nil

	-- Transform adventurer to UI ViewModel
	local vm = useMemo(function()
		if not adventurer then
			return nil
		end
		return AdventurerViewModel.fromAdventurer(adventurer)
	end, { adventurer } :: { any })

	local inventoryState = useInventoryState()
	local controller = useAdventurerDetailScreenController({
		adventurerId = safeAdventurerId,
		inventoryState = inventoryState,
		guildActions = guildActions,
	})

	local layoutViewModel = useMemo(function()
		if not vm then
			return nil
		end
		return AdventurerEquipmentLayoutViewModel.build({
			adventurerViewModel = vm,
			selectedSlotId = controller.selectedSlotId,
			pickerItems = controller.pickerItems,
		})
	end, { vm, controller.selectedSlotId, controller.pickerItems } :: { any })

	if not adventurerId then
		return e(VStack, {
			Size = UDim2.fromScale(1, 1),
			Align = "Center",
			Justify = "Center",
		}, {
			ErrorText = e(Text, {
				Text = "No adventurer selected.",
				Variant = "body",
				Color = "Text.Muted",
				Size = UDim2.fromScale(0.8, 0.1),
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
	end

	if not vm or not layoutViewModel then
		return e(VStack, {
			Size = UDim2.fromScale(1, 1),
			Align = "Center",
			Justify = "Center",
		}, {
			ErrorText = e(Text, {
				Text = "Adventurer not found.",
				Variant = "body",
				Color = "Text.Muted",
				Size = UDim2.fromScale(0.8, 0.1),
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
	end

	return e(AdventurerDetailScreenView, {
		containerRef = anim.containerRef,
		adventurerTypeLabel = vm.TypeLabel,
		layoutViewModel = layoutViewModel,
		onBack = function()
			soundActions.playMenuClose("AdventurerDetail")
			navActions.goBack()
		end,
		onSelectSlot = controller.onSelectSlot,
		onUnequipSlot = controller.onUnequipSlot,
		onSelectPickerItem = controller.onSelectPickerItem,
	})
end

return AdventurerDetailScreen
