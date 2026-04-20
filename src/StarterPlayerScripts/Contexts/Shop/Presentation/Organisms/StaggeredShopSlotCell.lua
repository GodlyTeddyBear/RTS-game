--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)

local ShopSlotCell = require(script.Parent.ShopSlotCell)
local ShopSlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ShopSlotViewModel)

--[=[
	@interface TStaggeredShopSlotCellProps
	Props for a staggered shop grid cell (wraps ShopSlotCell with animation).
	.Item ShopSlotViewModel.TShopSlotViewModel -- Item to display
	.IsSelected boolean -- Whether this cell is currently selected
	.OnSelect (item: ShopSlotViewModel.TShopSlotViewModel) -> () -- Selection callback
	.LayoutOrder number -- Grid layout order
	.Index number -- Position in grid (used for stagger timing)
]=]
export type TStaggeredShopSlotCellProps = {
	Item: ShopSlotViewModel.TShopSlotViewModel,
	IsSelected: boolean,
	OnSelect: (item: ShopSlotViewModel.TShopSlotViewModel) -> (),
	LayoutOrder: number,
	Index: number,
}

--[=[
	@class StaggeredShopSlotCell
	Wraps ShopSlotCell with staggered mount animation. Grid cells appear sequentially rather than all at once.
	@client
]=]

--[=[
	Render a shop cell with staggered entrance animation.
	@within StaggeredShopSlotCell
	@param props TStaggeredShopSlotCellProps
	@return React.ReactElement? -- Grid cell or nil during stagger delay
]=]
local function StaggeredShopSlotCell(props: TStaggeredShopSlotCellProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.Grid)

	if not isVisible then
		return nil
	end

	return e(ShopSlotCell, {
		Item = props.Item,
		IsSelected = props.IsSelected,
		OnSelect = props.OnSelect,
		LayoutOrder = props.LayoutOrder,
	})
end

return StaggeredShopSlotCell
