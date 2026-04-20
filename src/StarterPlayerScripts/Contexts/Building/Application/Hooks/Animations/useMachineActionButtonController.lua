--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ButtonHelpers = require(script.Parent.Parent.Parent.Parent.Parent.App.Presentation.Atoms.ButtonHelpers)
local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)

local useEffect = React.useEffect
local useRef = React.useRef

local ERROR_FLASH_SCALE = 1.07

--[=[
	@type TMachineActionButtonController
	@within useMachineActionButtonController
	.wrapRef { current: Frame? } -- Ref for the button wrapper frame
]=]
export type TMachineActionButtonController = {
	wrapRef: { current: Frame? },
}

--[=[
	Manages the error-flash spring animation for a single machine action button.
	Owns the wrapper ref, UIScale ref, and both animation effects.
	@within useMachineActionButtonController
	@param actionKey string -- Unique key for this action
	@param errorFlashKey string -- Key of the action currently showing error
	@param errorFlashGeneration number -- Counter that increments to trigger flash
	@return TMachineActionButtonController -- Refs to attach to the wrapper frame
]=]
local function useMachineActionButtonController(
	actionKey: string,
	errorFlashKey: string,
	errorFlashGeneration: number
): TMachineActionButtonController
	local wrapRef = useRef(nil :: Frame?)
	local uiScaleRef = useRef(nil :: UIScale?)

	useEffect(function()
		local frame = wrapRef.current
		if frame then
			uiScaleRef.current = ButtonHelpers.ensureUIScale(frame)
		end
		return function()
			uiScaleRef.current = nil
		end
	end, {})

	useEffect(function()
		if errorFlashGeneration == 0 then
			return
		end
		if errorFlashKey ~= actionKey then
			return
		end
		local uiScale = uiScaleRef.current
		if not uiScale then
			return
		end
		local dampingRatio, frequency = ButtonHelpers.getSpringParams("Bouncy")
		spr.target(uiScale, dampingRatio, frequency, {
			Scale = ERROR_FLASH_SCALE,
		})
		spr.completed(uiScale, function()
			if uiScale.Parent and uiScaleRef.current == uiScale then
				spr.target(uiScale, dampingRatio, frequency, {
					Scale = 1,
				})
			end
		end)
	end, { errorFlashGeneration, errorFlashKey, actionKey } :: { any })

	return {
		wrapRef = wrapRef,
	}
end

return useMachineActionButtonController
