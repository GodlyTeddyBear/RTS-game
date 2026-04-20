--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useRef = React.useRef
local useEffect = React.useEffect

local AnimationTokens = require(script.Parent.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useSpring = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useSpring)
local useReducedMotion = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)
local useCountUp = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useCountUp)

local ShopSlotViewModel = require(script.Parent.Parent.Parent.ViewModels.ShopSlotViewModel)

--[=[
	@interface TShopDetailPanelController
	@within useShopDetailPanelController
	Refs, animated values, and stable callbacks for the Shop detail panel.
	.contentRef { current: TextButton? } -- Ref for the inner slot button (entrance animation target)
	.addBtnRef { current: TextButton? } -- Ref for the quantity increment button
	.minusBtnRef { current: TextButton? } -- Ref for the quantity decrement button
	.addHover table -- Hover spring callbacks for the increment button
	.minusHover table -- Hover spring callbacks for the decrement button
	.animatedCost string -- Animated cost counter display string
]=]
export type TShopDetailPanelController = {
	contentRef: { current: TextButton? },
	addBtnRef: { current: TextButton? },
	minusBtnRef: { current: TextButton? },
	addHover: { onMouseEnter: () -> (), onMouseLeave: () -> (), onActivated: (cb: () -> ()) -> () -> () },
	minusHover: { onMouseEnter: () -> (), onMouseLeave: () -> (), onActivated: (cb: () -> ()) -> () -> () },
	animatedCost: string,
}

--[=[
	@function useShopDetailPanelController
	@within useShopDetailPanelController
	Owns all animation orchestration for the Shop detail panel: entrance spring, hover springs for quantity buttons, and the animated cost counter.
	@param item ShopSlotViewModel.TShopSlotViewModel? -- Currently selected item (drives entrance animation)
	@param totalCost number -- Current total cost (drives animated counter)
	@return TShopDetailPanelController
]=]
local function useShopDetailPanelController(
	item: ShopSlotViewModel.TShopSlotViewModel?,
	totalCost: number
): TShopDetailPanelController
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()
	local contentRef = useRef(nil :: TextButton?)
	local addBtnRef = useRef(nil :: TextButton?)
	local minusBtnRef = useRef(nil :: TextButton?)

	local addHover = useHoverSpring(addBtnRef, AnimationTokens.Interaction.ActionButton)
	local minusHover = useHoverSpring(minusBtnRef, AnimationTokens.Interaction.ActionButton)

	local animatedCost = useCountUp(totalCost, {
		Duration = 0.2,
		Prefix = "Cost: ",
	})

	-- Animate content entrance when the selected item changes
	useEffect(function()
		if not item or not contentRef.current or prefersReducedMotion then
			return
		end
		contentRef.current.Size = UDim2.fromScale(0.95157 * 0.95, 0.97467 * 0.95)
		spring(contentRef, {
			Size = UDim2.fromScale(0.95157, 0.97467),
		}, "Responsive")
	end, { item } :: { any })

	return {
		contentRef = contentRef,
		addBtnRef = addBtnRef,
		minusBtnRef = minusBtnRef,
		addHover = addHover,
		minusHover = minusHover,
		animatedCost = animatedCost,
	}
end

return useShopDetailPanelController
