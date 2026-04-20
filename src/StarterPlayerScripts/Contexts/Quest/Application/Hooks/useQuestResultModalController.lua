--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useSpring)
local useReducedMotion = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)

export type TQuestResultModalController = {
	backdropRef: { current: CanvasGroup? },
	cardRef: { current: Frame? },
	scaleRef: { current: UIScale? },
}

local function useQuestResultModalController(): TQuestResultModalController
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()
	local backdropRef = React.useRef(nil :: CanvasGroup?)
	local cardRef = React.useRef(nil :: Frame?)
	local scaleRef = React.useRef(nil :: UIScale?)

	React.useEffect(function()
		local backdrop = backdropRef.current
		local scale = scaleRef.current
		if not backdrop or not scale then
			return
		end

		if prefersReducedMotion then
			backdrop.GroupTransparency = 0
			scale.Scale = 1
			return
		end

		backdrop.GroupTransparency = 1
		scale.Scale = 0.8
		spring(backdropRef :: any, { GroupTransparency = 0 }, "Responsive")
		spring(scaleRef :: any, { Scale = 1 }, "Bouncy")
	end, { prefersReducedMotion })

	return {
		backdropRef = backdropRef,
		cardRef = cardRef,
		scaleRef = scaleRef,
	}
end

return useQuestResultModalController
