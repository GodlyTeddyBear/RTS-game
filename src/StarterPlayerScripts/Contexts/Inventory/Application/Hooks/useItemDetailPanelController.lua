--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useRef = React.useRef
local useEffect = React.useEffect

local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useSpring)
local useReducedMotion = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)
local useAnimatedVisibility = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useAnimatedVisibility)
local InventorySlotViewModel = require(script.Parent.Parent.ViewModels.InventorySlotViewModel)

--[=[
	@interface TItemDetailPanelController
	@within useItemDetailPanelController
	.shouldRenderNothing boolean -- Hide panel entirely (never selected)
	.shouldRenderEmpty boolean -- Show empty placeholder (transitioning)
	.emptyContainerRef { current: Frame? } -- Container for empty state animation
	.contentRef { current: Frame? } -- Container for item content with size animation
	.actionButtonRef { current: TextButton? } -- Action button for hover effects
	.onActionMouseEnter () -> () -- Hover enter handler
	.onActionMouseLeave () -> () -- Hover leave handler
	.onActionActivated () -> () -- Button activated handler
]=]
export type TItemDetailPanelController = {
	shouldRenderNothing: boolean,
	shouldRenderEmpty: boolean,
	emptyContainerRef: { current: Frame? },
	contentRef: { current: Frame? },
	actionButtonRef: { current: TextButton? },
	onActionMouseEnter: () -> (),
	onActionMouseLeave: () -> (),
	onActionActivated: () -> (),
}

--[=[
	@function useItemDetailPanelController
	@within useItemDetailPanelController
	Manage detail panel visibility, animation, and button interactions.
	@param item InventorySlotViewModel? -- Selected item or nil
	@param onAction ((actionName: string) -> ())? -- Action button callback
	@return TItemDetailPanelController
]=]
local function useItemDetailPanelController(
	item: InventorySlotViewModel.TInventorySlotViewModel?,
	onAction: ((actionName: string) -> ())?
): TItemDetailPanelController
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()
	local contentRef = useRef(nil :: Frame?)
	local actionButtonRef = useRef(nil :: TextButton?)
	local actionHover = useHoverSpring(actionButtonRef, AnimationTokens.Interaction.ActionButton)
	local emptyVisibility = useAnimatedVisibility(item == nil, AnimationTokens.Panel.DetailPanel)

	useEffect(function()
		if not item or not contentRef.current or prefersReducedMotion then
			return
		end

		-- Start content at 95% scale and animate to full size if motion is not reduced
		contentRef.current.Size = UDim2.fromScale(0.95157 * 0.95, 0.97467 * 0.95)
		spring(contentRef, {
			Size = UDim2.fromScale(0.95157, 0.97467),
		}, "Responsive")
	end, { item } :: { any })

	-- Dispatch action callback when button is activated
	local function onActionActivated()
		if onAction then
			onAction("action")
		end
	end

	-- Visibility logic: render nothing while animating out, show empty state while transitioning
	local shouldRenderNothing = not emptyVisibility.shouldRender and not item
	local shouldRenderEmpty = emptyVisibility.shouldRender and not item

	return {
		shouldRenderNothing = shouldRenderNothing,
		shouldRenderEmpty = shouldRenderEmpty,
		emptyContainerRef = emptyVisibility.containerRef,
		contentRef = contentRef,
		actionButtonRef = actionButtonRef,
		onActionMouseEnter = actionHover.onMouseEnter,
		onActionMouseLeave = actionHover.onMouseLeave,
		onActionActivated = actionHover.onActivated(onActionActivated),
	}
end

return useItemDetailPanelController
