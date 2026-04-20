--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useItemDetailPanelController =
	require(script.Parent.Parent.Parent.Application.Hooks.useItemDetailPanelController)
local ItemDetailPanelView = require(script.Parent.ItemDetailPanelView)

local InventorySlotViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.InventorySlotViewModel)

--[=[
	@interface TItemDetailPanelProps
	@within ItemDetailPanel
	.Item InventorySlotViewModel? -- Selected item or nil
	.OnAction ((actionName: string) -> ())? -- Action button callback
]=]
export type TItemDetailPanelProps = {
	Item: InventorySlotViewModel.TInventorySlotViewModel?,
	OnAction: ((actionName: string) -> ())?,
}

--[=[
	@function ItemDetailPanel
	@within ItemDetailPanel
	Container component for the detail panel with animation and visibility control.
	@param props TItemDetailPanelProps
	@return React.ReactElement?
]=]
local function ItemDetailPanel(props: TItemDetailPanelProps)
	local controller = useItemDetailPanelController(props.Item, props.OnAction)
	if controller.shouldRenderNothing then
		return nil
	end

	return e(ItemDetailPanelView, {
		Item = props.Item,
		ShouldRenderEmpty = controller.shouldRenderEmpty,
		EmptyContainerRef = controller.emptyContainerRef,
		ContentRef = controller.contentRef,
		ActionButtonRef = controller.actionButtonRef,
		OnActionMouseEnter = controller.onActionMouseEnter,
		OnActionMouseLeave = controller.onActionMouseLeave,
		OnActionActivated = controller.onActionActivated,
	})
end

return ItemDetailPanel
