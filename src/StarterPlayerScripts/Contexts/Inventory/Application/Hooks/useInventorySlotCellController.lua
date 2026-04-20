--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local InventorySlotViewModel = require(script.Parent.Parent.ViewModels.InventorySlotViewModel)

--[=[
	@interface TInventorySlotCellController
	@within useInventorySlotCellController
	.buttonRef { current: TextButton? } -- Button element reference
	.onMouseEnter () -> () -- Hover enter handler
	.onMouseLeave () -> () -- Hover leave handler
	.onActivated () -> () -- Button activated handler
	.isSelected boolean -- Whether this slot is currently selected
	.decoreStroke ColorSequence -- Decoration stroke gradient (gold or default)
	.itemIcon string? -- Item icon path or nil
	.nameAbbr string -- 2-letter abbreviation of item name or "?"
	.showQuantity boolean -- Whether to display quantity badge
]=]
export type TInventorySlotCellController = {
	buttonRef: { current: TextButton? },
	onMouseEnter: () -> (),
	onMouseLeave: () -> (),
	onActivated: () -> (),
	isSelected: boolean,
	decoreStroke: ColorSequence,
	itemIcon: string?,
	nameAbbr: string,
	showQuantity: boolean,
}

--[=[
	@function useInventorySlotCellController
	@within useInventorySlotCellController
	Manage individual slot cell state: hover effects, selection, and display data.
	@param item InventorySlotViewModel -- Slot data
	@param onSelect ((item: InventorySlotViewModel) -> ())? -- Selection callback
	@param isSelected boolean? -- Whether slot is currently selected
	@return TInventorySlotCellController
]=]
local function useInventorySlotCellController(
	item: InventorySlotViewModel.TInventorySlotViewModel,
	onSelect: ((item: InventorySlotViewModel.TInventorySlotViewModel) -> ())?,
	isSelected: boolean?
): TInventorySlotCellController
	local resolvedIsSelected = isSelected or false
	-- Gold stroke for selected slots, default for unselected
	local decoreStroke = if resolvedIsSelected then GradientTokens.GOLD_STROKE_SUBTLE else GradientTokens.SLOT_DECORE_STROKE
	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.SlotCell)

	-- Invoke callback when slot is clicked
	local function onActivated()
		if onSelect then
			onSelect(item)
		end
	end

	local showQuantity = (item.Quantity or 0) > 1 -- Only show badge if quantity > 1
	local itemIcon = item.ItemIcon

	return {
		buttonRef = buttonRef,
		onMouseEnter = hover.onMouseEnter,
		onMouseLeave = hover.onMouseLeave,
		onActivated = hover.onActivated(onActivated),
		isSelected = resolvedIsSelected,
		decoreStroke = decoreStroke,
		itemIcon = itemIcon,
		nameAbbr = item.NameAbbr,
		showQuantity = showQuantity,
	}
end

return useInventorySlotCellController
